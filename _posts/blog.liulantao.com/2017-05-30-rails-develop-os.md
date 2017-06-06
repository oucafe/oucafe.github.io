---
layout: post
title: "选择适合 Rails 开发的操作系统"
time: 2017-06-06
site_name: liulantao.com
source_url: http://blog.liulantao.com/rails-develop-os.html
categories: [Technology]
tags: [Ruby]
permalink: /rails-develop-os.html
---

有人说 Ubuntu，
有人说 Linux Mint，
也有人偏好 MacOS，
甚至用 Windows。

到底应该怎么选择适合 Rails 开发的操作系统呢？

<!--excerpt-->

### 部署环境是什么系统？

选择与部署环境实用的操作系统一致是最好的策略，
可以降低因兼容性造成 bug 的可能性。

例如，
生产环境使用的是 Ubuntu Server 16.04，
最好的开发环境肯定是 Ubuntu Desktop 16.04。

### Ruby 版本

Linux 发行版大都预装某个版本的 Ruby，
或者可以通过自带的包管理器来安装。

*核对 Ruby 版本*，
确保安装的 Ruby 版本属于 Rails 支持的版本。

*使用 RVM 或 rbenv*，
以便安装新版本的 Ruby。
Ruby 包版本管理器的作用不仅仅是安装最新的 Ruby，还能够方便在新旧版本直接切换，以及管理 gem 集合。

如果开发的代码将被部署到服务器上，
使用部署环境支持的 Ruby 版本。

片面追求使用最新版本可能导致代码不工作。

### 运行环境与编辑环境隔离

把运行环境和开发编辑环境隔离是一个好主意，可以用到熟悉的开发工具／IDE。

如果不想使用 Linux，
或者没有熟悉的 IDE，
还有另一个选择：
使用 Vagrant，
安装 Ubuntu Server（或选定的其它系统），
然后挂载本地开发目录。
只需在 Vagrant 虚拟机里运行命令，
在宿主机（可以是 Windows）上进行编码开发工作。

但是，
对于充满求知欲（以及决心克服困难）的初学者，
建议直接使用一个 Linux 发行版作为开发环境，
以便能够学习解决服务器环境可能遇到的各种问题。

### Windows ？

是否选择 Windows，是一个容易困惑的问题。

别用 Windows————除非要部署在 Windows 环境。
有些 gem 在 Windows 系统下不能正常工作。

如果不知道部署的目标环境是什么系统，建立一个**虚拟的**部署环境。
在 Windows 上安装 VirtualBox，
在其中建立 Linux 虚拟机。

用这种方式，构建出开发部署的流程。

### 另一种思路：Docker

如果仅作 Ruby 开发，
Docker 有时候比 VirtualBox 方便。

Docker 能够更容易建立所需任何系统的运行环境。
可以在任何宿主机上轻松建立出 Ubuntu Server 的容器来运行 Rails 应用。

使用虚拟机需要关注的主要问题是宿主机与虚拟机的代码和操作同步。
使用 Docker 可以忽略哪些代码同步的工作，
如 FTP／SFTP／RSYNC 等。

Docker Toolbox for Windows 基于 VirtualBox 或 Hyper-V，支持在 Windows 上运行 Linux 内核。

### 总结

* 保持与服务器一致的运行环境
* 关注并管理 Ruby 版本
* 使用熟悉的 IDE
* 构建“开发-部署”流程
* 使用虚拟环境，如果有必要
