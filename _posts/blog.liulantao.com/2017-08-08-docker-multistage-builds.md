---
layout: post
title: "多步构建 | Docker 瘦身之旅"
categories: [Technology]
tags: [CI/CD, Docker, Multi-stage, Multi Stage, Build]
permalink: /docker-multistage-builds.html
date: Aug 8, 2017
---

软件生命周期管理中，`CI/CD` 体系引入 `Docker` 以提升开发效率形成共识；
然而 `Docker` 构建出的镜像体积太大，成为令人头疼的问题。
解决思路，除了选择较小的基础镜像（base image），在构建过程对新增内容进行选择，也是控制镜像体积的有效途径。

[Docker 17.05][] 引入 [多步构建][Multi-stage builds]，特别有助于**高效构建精简镜像**。
<!--excerpt-->

本文对比几种模式，它们在配置文件、构建步骤、输出体积、数据安全性等方面的区别。
*构建过程涉及广泛，其中的其它技巧，则不在本文讨论，如有需求可以关注本博客后续文章或联系作者交流。*

<!--excerpt-->

[TL;DR][use multistage builds]

### 几种构建模式（与反模式）

在运维体系中引入 `Docker`，一般先确定一种构建模式。
构建模式的选择，对容器运维的敏捷性、安全性、有效性关系重大，最终会反馈到业务层面。
系统运维则是对投入/产出的综合权衡(和相互妥协)的过程。

---

### 1. `All-in-One（全包）`反模式

`All-in-One（全包）`模式，顾名思义，将全部步骤放在一个容器中。

特点是：

+ 配置文件：简单；
+ 构建步骤：直接；
- 输出体积：大；
- 安全性：低（包含源码）。

#### 镜像的 Dockerfile

“依赖——源码——编译测试——安装” 一条龙

```
#> Dockerfile
FROM debian:stable-slim
RUN apt-get update -qq && apt-get install -qq -y --no-install-recommends g++ make > /dev/null && rm -rf /var/lib/apt/lists/*
COPY . .
RUN make && make test
CMD ./helloworld
```

#### 构建步骤

```
#> build-image.sh
#!/bin/bash
TARGET=helloworld:1-all-in-one
docker build -t ${TARGET} .
docker history ${TARGET} -H
```

#### 构建结果

1. 依赖包安装这一步，产生了 141MB 的层，而部署的只是 `hello world`；
2. 镜像包含源码；
3. 镜像包含编译步骤产生 11.7kB；
4. 没有安装步骤，所有没有其它数据；

```
Successfully built 0adc82634adc
Successfully tagged helloworld:1-all-in-one
IMAGE               CREATED             CREATED BY                                      SIZE                COMMENT
0adc82634adc        1 second ago        /bin/sh -c #(nop)  CMD ["/bin/sh" "-c" "./...   0B                  
350a2514a50c        2 seconds ago       /bin/sh -c make && make test                    11.7kB              
dab0fd3a2ae1        4 seconds ago       /bin/sh -c #(nop) COPY dir:9400a5be3c63dc0...   586B                
47f01058965c        5 seconds ago       /bin/sh -c apt-get update -qq && apt-get i...   141MB               
39a2bd166284        2 weeks ago         /bin/sh -c #(nop)  CMD ["bash"]                 0B                  
<missing>           2 weeks ago         /bin/sh -c #(nop) ADD file:2e683831f8c8f60...   55.2MB                         
```
*注 1：使用其它版本的体积可能有区别。如换用 `debian:stable`，基础镜像层为 `100MB`， 编译工具层为 `154MB`*
*注 2：当前的 `debian:stable` 对应 `debian:stretch` / `debian:9`*

---

### 2. `Builder` 模式

`Builder`（构建者）模式，是一种有效的模式——无论对于容器，还是在容器之前基于软件包的运维管理中。

`Builder` 模式为了解决编译产生的中间数据问题，引入额外的 `Builder 镜像`。
`Builder` 镜像的职责是负责软件源代码初始化、编译、测试的一系列操作，产生有效的用于部署的输出（软件二进制、jar 包等）
`Builder` 镜像的输出用于构建最终的应用镜像，中间过程的数据则弃之不用。

- 配置文件：中等；
- 构建步骤：复杂；
+ 输出体积：小；
+ 安全性：高。

#### 增加的 `Builder 镜像`

`Builder 镜像`包含了“依赖安装——源码准备——编译测试”的步骤。

```
#> cat Dockerfile.builder
FROM debian:stable-slim
RUN apt-get update -qq && apt-get install -qq -y --no-install-recommends g++ make > /dev/null && rm -rf /var/lib/apt/lists/*
COPY . .
RUN make && make test
```

#### 修改后的主镜像

`主镜像`只安装编译后的程序二进制文件。

```
#> cat Dockerfile
FROM debian:stable-slim
COPY helloworld helloworld
CMD ["./helloworld"]
```

#### 构建步骤

分两步进行构建：

1. 编译测试（Step 1.1），并从镜像中抽取二进制文件（Step 1.2）
2. 安装程序二进制文件

```
#> cat build-image.sh
#!/bin/bash
TARGET=helloworld:2-builder-pattern

# -- Step 1.1
BUILDER="helloworld:2-builder-pattern_intermediate"
docker build -t ${BUILDER} -f Dockerfile.builder .

# -- Step 1.2
BUILDER_CONTAINER="2-builder-pattern_intermediate_container"
docker create --name ${BUILDER_CONTAINER} ${BUILDER}
docker cp ${BUILDER_CONTAINER}:./helloworld ./
docker rm -f ${BUILDER_CONTAINER}

# -- Step 2
docker build -t ${TARGET} .
docker history ${TARGET} -H
```

#### 构建结果

从体积上看很让人振奋：

1. 依赖包安装、源码、编译测试过程的输出，全部排除在最终镜像之外；
4. 二进制安装步骤，只有 9.13kB。

```
Successfully built b9c8ca299b2f
Successfully tagged helloworld:2-builder-pattern
IMAGE               CREATED                  CREATED BY                                      SIZE                COMMENT
b9c8ca299b2f        Less than a second ago   /bin/sh -c #(nop)  CMD ["./helloworld"]         0B                  
c1a54d5783c3        1 second ago             /bin/sh -c #(nop) COPY file:c38254f0cce19a...   9.13kB              
39a2bd166284        2 weeks ago              /bin/sh -c #(nop)  CMD ["bash"]                 0B                  
<missing>           2 weeks ago              /bin/sh -c #(nop) ADD file:2e683831f8c8f60...   55.2MB              
```

---

### 3. Multi-stage builds 多步构建

基于 `Dockerfile` 支持的 `multistage-build`，在 `Builder 模式`基础上进一步优化流程。

+ 配置文件：简单；
+ 构建步骤：直接；
+ 输出体积：小；
+ 安全性：高。

#### 修改后的镜像

1. 以`全包模式`为基础，利用额外的 `FROM ... [AS ...]` 语法，定义一个用于“安装依赖——源码准备——编译测试”的临时容器镜像；
2. 主镜像从临时容器镜像中复制二进制文件进行安装。

```
# Dockerfile
FROM debian:stable-slim as builder
RUN apt-get update -qq && apt-get install -qq -y --no-install-recommends g++ make > /dev/null  && rm -rf /var/lib/apt/lists/*
COPY . .
RUN make && make test

FROM debian:stable-slim
COPY --from=builder ./helloworld ./
CMD ["./helloworld"]
```

#### 构建步骤

与`全包模式`相同，比 `builder 模式`简单直接。

```
#> build-image.sh
#!/bin/bash
TARGET=helloworld:3-multistage
docker build -t ${TARGET} .
docker history ${TARGET} -H
```

#### 构建结果

体积与 `Builder 模式`完全相同：

1. 依赖包安装、源码、编译测试过程的输出，全部排除在最终镜像之外；
4. 二进制安装步骤，只有 9.13kB。

```
Successfully built af20ba44b07c
Successfully tagged helloworld:3-multistage
IMAGE               CREATED             CREATED BY                                      SIZE                COMMENT
af20ba44b07c        20 seconds ago      /bin/sh -c #(nop)  CMD ["./helloworld"]         0B                  
aa4575d4f6eb        22 seconds ago      /bin/sh -c #(nop) COPY file:9a23de25d36df9...   9.13kB              
a20fd0d59cf1        2 weeks ago         /bin/sh -c #(nop)  CMD ["bash"]                 0B                  
<missing>           2 weeks ago         /bin/sh -c #(nop) ADD file:ebba725fb97cea4...   100MB               
```

---

### 总结：[采用多步构建！][use multistage builds] <a id="use-multistage-builds"></a>

在输出方面，`Builder 模式` 与 `多步构建` 都能满足要求；
而在易用性方面，`多步构建` 明显胜出。
因此，在流程中应尽可能多的采用多步构建。

[Docker 17.05]: <https://docs.docker.com/release-notes/docker-ce/#17050-ce-2017-05-04>
[Multi-stage builds]: <https://docs.docker.com/engine/userguide/eng-image/multistage-build/> "Multi-stage builds"
[use multistage builds]: <#use-multistage-builds>
