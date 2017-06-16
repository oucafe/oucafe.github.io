---
layout: post
title: 编写一个 Unix Shell - 第一部分
categories: [Technology]
tags: ['recurse-center', 'unix', 'operating-systems', 'C', 'shell']
excerpt: '按部件来构建自己的 UNIX shell。这篇文章的重点是系统调用 fork 的语义'
date: Jun 9, 2017
author: Indradhanush Gupta
src: https://raw.githubusercontent.com/indradhanush/indradhanush.github.io/master/_posts/blog/2017-05-28-writing-a-unix-shell-part-1.md
permalink: /writing-a-unix-shell-part-1.html
---

（译自 https://indradhanush.github.io）

我正在 RC（Recurse Center，纽约市的一个程序员教育特色社区，译者注）尝试一个项目，就是编写 UNIX shell。
这是将要发布的一系列帖子的第一篇。

## 什么是 Shell？

很多人都写了这一点，所以我不会太涉及这个定义的细节。
然而，用一句话来概括 -

> Shell 是一个接口，使您可以与操作系统内核进行交互。

## Shell 如何工作？

Shell 解析用户输入的命令并执行此操作。
为了能够做到这一点，shell 的工作流程是这样的：

1. 启动 shell
2. 等待用户输入
3. 解析用户输入
4. 执行命令并返回结果
5. 返回到 `2`。

所有这一切都有一个重要的原因：进程。
Shell 是父进程。
它是我们程序的 `main` 线程，等待用户输入。
但是，我们不能在 `main` 线程本身中执行命令，原因如下：

1. 错误的命令会导致整个 shell 停止工作。
   我们想避免这种情况。
2. 独立命令应该有自己的进程块。
   我们称之为隔离，属于容错的范畴。

## Fork（复刻／分叉）

为了能够避免这种情况，我们使用系统调用 `fork`。
我原以为自己理解 `fork`，直到用它写了四行代码。

`fork` 创建当前进程的副本。
该副本称为 `child`，系统中的每个进程都有与之相关联的唯一进程标识（pid）。
我们来看看下面的代码：

[<i>fork.c</i>]({{ site.url }}/3rd/indradhanush.github.io/code/shell-part-1/fork.c)
{% highlight c linenos %}
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int
main() {
    pid_t child_pid = fork();

    // The child process
    if (child_pid == 0) {
        printf("### Child ###\nCurrent PID: %d and Child PID: %d\n",
               getpid(), child_pid);
    } else {
        printf("### Parent ###\nCurrent PID: %d and Child PID: %d\n",
               getpid(), child_pid);
    }

    return 0;
}
{% endhighlight %}


`fork` 系统调用返回两次，每个进程一次。
起初听起来与直觉相反。
那就让我们来看看在底层发生的事情。

1. 通过调用 `fork`，我们在程序中创建一个新的分支。
   这与传统的 `if-else` 分支不同。
   `fork` 创建一个当前进程的副本，并创建一个新的进程。
   结束的系统调用返回了子进程的进程 ID。

2. 在 `fork` 调用成功之后，子进程和父进程（我们代码的主线程）同时运行。

为了让您更好地了解程序流程，请查看此图：

<figure>
	<img src="{{ site.url }}/3rd/indradhanush.github.io/images/fork.jpg" alt="fork" />
</figure>

`fork()` 创建一个新的子进程，但与此同时，父进程的执行并不停止。
子进程开始并完成执行的过程，独立于父进程的执行，反之亦然。

在我们进一步进行之前快速声明一下，`getpid` 系统调用返回当前的进程 id。

如果编译并执行代码，您将得到类似于以下内容的输出：

```
### Parent ###
Current PID: 85247 and Child PID: 85248
### Child ###
Current PID: 85248 and Child PID: 0
```

在 `### Parent ###` 下的块中，当前进程 ID 为 `85247`，子进程的为 `85248`。
需要注意的是子进程的 pid 比父进程大，这意味着子进程是在父进程之后创建的。

在 `### Child ###` 下的块中，当前进程 ID 为 `85248`，这与前一个块中的子进程的 pid 相同。
但是，这里子进程的 pid 是 `0`。

实际数字在每次执行时可能有所不同。

当在 `代码第 9 行` 已经明确地为 `child_pid` 赋值后，`child_pid` 在同一个执行流程中怎么能够获取到两个不同的值？有这种想法情有可原。
然而，记住，调用 `fork` 创建出了一个与当前进程相同的新进程。
因此，在父进程中，`child_pid` 是刚刚创建的子进程的实际值，子进程本身没有自己的子进程，结果 `child_pid` 的值为 `0`。

因此，我们从第 12 行到第 16 行定义的 `if-else` 块是必需的，用来控制在子代与父级分别执行的代码。
当 `child_pid` 为 `0` 时，代码块将在子进程下执行，而 else 块将在父进程下执行。
块被执行的顺序无法确定，取决于操作系统的调度器。

## 确定性简介

让我来介绍一下 `sleep` 系统调用。
引用 linux 手册：

> sleep -- suspend execution for an interval of time

时间间隔以秒为单位。

让我们给父进程添加一个 `sleep(1)` 调用，在代码的 `else` 块：

[<i>sleep_parent.c</i>]({{ site.url }}/3rd/indradhanush.github.io/code/shell-part-1/sleep_parent.c)
{% highlight c linenos %}
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int
main() {
    pid_t child_pid = fork();

    // The child process
    if (child_pid == 0) {
        printf("### Child ###\nCurrent PID: %d and Child PID: %d\n",
               getpid(), child_pid);
    } else {
        sleep(1); // Sleep for one second
        printf("### Parent ###\nCurrent PID: %d and Child PID: %d\n",
               getpid(), child_pid);
    }

    return 0;
}
{% endhighlight %}

而执行此操作时，输出将类似于：

```
### Child ###
Current PID: 89743 and Child PID: 0
```

and after a span of 1 second, you would see

```
### Parent ###
Current PID: 89742 and Child PID: 89743
```

每次执行代码时，都会看到相同的行为。
这是因为我们在父进程中执行了阻塞式的 `sleep` 调用，
于此同时操作系统调度器寻找到空闲 CPU 时间片执行子进程。

类似地，如果把 `sleep(1)` 调用加到子进程，即代码的 `if` 块，你会立即注意到这个父程序块的输出显示在控制台。
您也会注意到程序已经终止。
而子块的输出被转储到 `stdout`。
类似于：

```
$ gcc -lreadline blog/sleep_child.c -o sleep_child && ./sleep_child
### Parent ###
Current PID: 23011 and Child PID: 23012
$ ### Child ###
Current PID: 23012 and Child PID: 0
```

这段程序的源码在 [sleep_child.c]({{ site.url
}}/3rd/indradhanush.github.io/code/shell-part-1/sleep_child.c).

这是因为父进程在 `printf` 语句之后无事可做，被终止。
然而，子进程先在 `sleep` 调用中被阻塞一秒钟，再执行 `printf` 语句。

## 确定性的正确方式

然而，使用 `sleep` 来控制你的进程执行流程并不是最好的方法，
因为如果你做一次 `n秒` 的 `sleep` 调用：

1. 如何保证无论你等待任何操作，都能在这 `n秒` 内完成执行。
2. 如果你所等待的完成时间比 `n秒` 早很多，怎么办？
   在这种情况下是不必要的等待。

一个更好的方法是使用 `wait` 系统调用（或变体之一）。
我们来使用 `waitpid` 系统调用。
它需要以下参数：

1. 程序所等待进程的进程ID。
2. 一个用于填充进程终止方式信息的变量。
3. 可选标志位，定制 `waitpid` 的行为

[<i>wait.c</i>]({{ site.url }}/3rd/indradhanush.github.io/code/shell-part-1/wait.c)
{% highlight c linenos %}
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int
main() {
    pid_t child_pid;
    pid_t wait_result;
    int stat_loc;

    child_pid = fork();

    // The child process
    if (child_pid == 0) {
        printf("### Child ###\nCurrent PID: %d and Child PID: %d\n",
               getpid(), child_pid);
        sleep(1); // Sleep for one second
    } else {
        wait_result = waitpid(child_pid, &stat_loc, WUNTRACED);
        printf("### Parent ###\nCurrent PID: %d and Child PID: %d\n",
               getpid(), child_pid);
    }

    return 0;
}
{% endhighlight %}

当执行这个程序，你会注意到子块立即打印出来然后等待一个短暂的时刻（我们把 `sleep` 添加在 `printf` 后）。
父进程等待子进程执行完成后，它可以自由地执行自己的命令。

以上是第一部分。本文包含的所有代码都可以参看[这里](https://github.com/indradhanush/indradhanush.github.io/tree/master/code/shell-part-1/)。
在下一篇文章中，我们将探讨如何从用户输入读取命令并执行。
敬请关注。

## 致谢

感谢 [Saul Pwanson](https://github.com/saulpw) 帮助我理解 `fork` 的行为和 [Jaseem Abid](https://github.com/jaseemabid) 帮助阅读草稿并提出修改建议。

## 参考资料

- [EnthusiastiCon - Stefanie Schirmer “OMG building a shell in 10 minutes”](https://www.youtube.com/watch?v=k6TTj4C0LF0)
- [Linux man pages](https://linux.die.net/man/)
