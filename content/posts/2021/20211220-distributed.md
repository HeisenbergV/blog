---
title: "raft"
categories: [coder]
tags: [go,源码]
date: 2021-07-21
draft: true 
---


1. 实现简单版MapReduce
2. Raft算法实现
3. 利用Raft实现具有容错性的kv服务
4. kv具有复制功能，每个村处对象只存储部分数据

----

GFS论文提出的一些新思考:
1. 单数据中心
2. 大数据连续访问并非随机访问
3. 存储系统具备弱一致性也是可行的
4. 但master节点也可以很好的工作


https://blog.betacat.io/post/raft-implementation-in-etcd/
https://www.codedump.info/post/20180922-etcd-raft/
https://www.codedump.info/post/20180921-raft/
https://github.com/maemual/raft-zh_cn/blob/master/raft-zh_cn.md#51-raft-基础

raft相对于paxos
再保障了安全特性和效率的情况下又做到了下面的要求
1. 提供了一个完整的实际的系统实现基础
2. 比Paxos简单，提高了可理解性: 将算法分解为多个相对独立的子问题、减少状态数量

