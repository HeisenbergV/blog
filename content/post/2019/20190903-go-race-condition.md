---
title: "Go 竞态问题"
categories: [计算机]
tags: [go]
date: 2019-09-03
---

## 定义
- 单处理器中低优先级的进程被高优先级的进程抢占，同时他们访问同一块共享资源
- 多处理器中，CPU1的进程、CPU2的进程同时访问同一块共享资源

## 如何避免竞态条件
- 变量只读

```go
//下面两种获取map信息的方式
//懒汉获取方式,有则获取无则加载: 会有读写错乱情况
func loadmap(name string) int {
	return 2
}

func getmap2(name string) int {
	v, ok := maps[name]
	if !ok {
		v = loadmap(name)
		maps[name] = v
	}
	return v
}

//预先加载好, 使getmap只读, 就不会存在竞态问题
var maps = map[string]int{
	"a": 1,
	"b": 2,
	"c": 3,
}

func getmap(name string) int {
	return maps[name]
}

```

- 私有化变量

```go
//两个goroutine同时访问了变量a 引发竞态问题,导致结果不准确
var a = 0
var wg sync.WaitGroup //用于等待所有协程都完成

func add() {
	defer func() {
		wg.Done()
	}()
	for i := 0; i < 10000; i++ {
		a++
	}
}

func raceFunc1() {
	wg.Add(2)
	go add()
	go add()

	wg.Wait()
	fmt.Println("ok: ", a)
}
```
- Channel 靠通信同步数据而不是靠共享内存
```go
//使用channel 将a设置为goroutine的局部变量
var ch chan int

func add() {
	a := 0
	for i := 0; i < 10000; i++ {
		a++
	}
	ch <- a
}

func raceFunc1() {
	ch = make(chan int)
	go add()
	go add()

	v1, v2 := <-ch, <-ch
	fmt.Println("ok: ", v1+v2)
}
```

## 题外话: 空结构体
- 如何表达: struct{}是个 '空结构体类型', 和结构体不一样; struct{}{}是空结构体的值

```go
    //定义方式:
    var ss struct{} = struct{}{}
    ss := struct{}{}
    var ss struct{}
    
    //未初始化的空结构体, go会默认初始化成 struct{}{}类型
    //并且 空结构体的 值 只有 struct{}{} 其他都不行
    fmt.Println(ss) // {}
    
    var ss struct{} = nil //error
    var ss struct{} = 0 //error
    
    //比较
    a := struct{}{} // 或者写成 var a struct{}
    if a == struct{}{} { //不能用 nil或者0等
    	fmt.Print("11111") // print
    } else {
    	fmt.Print("22222")
    }
    fmt.Println(a) // {}
    a := struct{}{} 
    b := struct{}{}
    fmt.Println(a == b) // true
```

- 空结构体的内存占用是0

```go
a := struct{}{}
println(unsafe.Sizeof(a)) // 0
```
- 用途
    - 字典: 当我们想处理一些数据是否存在于字典的时候,我们只想关注key是否存在,value是不必要的,这时候可以用: map[string] struct{}
    - 信号: 当我们用channel来阻塞或者当一个信号触发的时候,我们只关注是否阻塞了,是否触发了,不在意传输的是什么信息: make(chan struct{})

- 举例
```go
//字典
m := make(map[string]struct{})
	
if _, ok := m["hello"]; ok {
	println("yes")
} else {
	println("no")
}
    
//信号
ch := make(chan struct{})
go func() {
	time.Sleep(time.Second)
	ch <- struct{}{}
}()

<-ch
fmt.Println("hello")
```

- ch:=make(chan struct{}, 100) 定义了有缓冲区的channel, 但缓冲区的内存大小依旧是0, cap(ch) 为100
- s := [100]struct{}{} 数组大小为100,占内存为0

## 防止竞态条件
- 临界区(critical section):在Lock和Unlock之间的代码段中的内容可以随便读取或者修改不会有竞态问题

- 一个只能为1和0的信号量叫做二元信号量(binary semaphore)
    - 生产消费模式
    - 可以设置访问数量
    - 官方扩展包支持:go get golang.org/x/sync/semaphore

```go

var (
	sema = make(chan struct{}, 1)//同一时刻 只能一个线程访问
	balance int
)

func Add(amount int) {
	sema <- struct{}{}  //写入成功 或者 失败阻塞住
	balance += amount
	<-sema
}

func Get() int {
	seam <- struct{}{}
	defer func() { <-seam }()
	return balance
}

```

- sync.Mutex互斥锁

```go
var (
	mu sync.Mutex // guards balance
	balance int
)

func Add(amount int) {
	mu.Lock()
	balance += amount
	mu.Unlock()
}

func Get() int{
	mu.Lock()
	defer func() {mu.Unlock()}()
	return balance
}
```
- sync.RWMutex读写锁
    - 如果只需要读取变量的状态，不修改变量,我们并发运行事实上是安全的，只要在运行的时候没有修改操作即可。在这种场景下我们需要一种特殊类型的锁，其允许多个只读操作并行执行，但写操作会完全互斥: 多读单写锁(multiple readers, single writer lock)
    - 适用场景:RWMutex只有当获得锁的大部分goroutine都是读操作, RWMutex需要更复杂的内部记录，所以比mutex慢些
    - 与Mutex比较
        - RWMutex是基于Mutex的，在Mutex的基础之上增加了读、写的信号量，并使用了类似引用计数的读锁数量
    
        - 读锁与读锁兼容，读锁与写锁互斥，写锁与写锁互斥，只有在锁释放后才可以继续申请互斥的锁
    - 使用
        - Lock()和Unlock()用于申请和释放写锁

        - RLock()和RUnlock()用于申请和释放读锁

```go
    var (
	rw sync.RWMutex 
	balance int
    )
    
    func Add(amount int) {
	rw.Lock()
	balance += amount
	rw.Unlock()
    }
    
    func Get() int{
	rw.Lock()
	defer func() {rw.Unlock()}()
	return balance
    }
```

- sync.Once惰性初始化
    - 判空后进行初始化操作,但多协程情况下容易出现竞态条件导致初始化多次

```go
gogo1 查性能
//线程安全但效率慢
var mu sync.Mutex 
var icons map[string]image.Image

// Concurrency-safe.
func Icon(name string) image.Image {
	mu.Lock()
	defer mu.Unlock()
	if icons == nil {
		loadIcons()
	}
	return icons[name]
}

//线程安全且高效,但代码复杂容易出错
var mu sync.RWMutex
var icons map[string]image.Image
func Icon(name string) image.Image {
	mu.RLock()
	if icons != nil {
		icon := icons[name]
		mu.RUnlock()
		return icon
	}
	mu.RUnlock()

    // acquire an exclusive lock
	mu.Lock()
	if icons == nil { // NOTE: must recheck for nil
		loadIcons()
	}
	icon := icons[name]
	mu.Unlock()
	return icon
}

//和读写锁一样,但更简洁
var loadIconsOnce sync.Once
var icons map[string]image.Image
// Concurrency-safe.
func Icon(name string) image.Image {
	loadIconsOnce.Do(loadIcons)
	return icons[name]
}
```
- 原子操作
    - 原子操作由底层硬件支持，而锁则由操作系统提供的API实现。若实现相同的功能，通常会更有效率
    - 支持增或减、比较并交换、载入、存储、交换

```go
//注意int关键字应该是 type int int64
//int 8字节, int32 4字节, int64 8字节 但int和int64操作一样但类型是不同的
var  counter int32 = 0
//加法
atomic.AddInt32(&counter, 1)
//减法
atomic.AddInt32(&counter, -1)
//比较并交换, 当counter的值和第二个参数(counter的旧值)不一致 会返回false 交换失败
atomic.CompareAndSwapInt32(&counter, 0, 12) //counter = 12
//载入(读取)
v:=atomic.LoadInt32(&counter)
//写入
atomic.StoreInt32(&counter, 22)
//交换
atomic.SwapInt32(&counter, 11)
```
- 自旋锁
    - 线程获取锁的时候，如果锁被其他线程持有，则当前线程将循环等待，直到获取到锁。
    - 自旋锁等待期间，线程的状态不会改变，线程一直是用户态并且是活动的(active)。
    - 自旋锁如果持有锁的时间太长，则会导致其它等待获取锁的线程耗尽CPU

```go
type spinLock uint32
func (sl *spinLock) Lock() {
	for !atomic.CompareAndSwapUint32((*uint32)(sl), 0, 1) {
		runtime.Gosched() //用于让出CPU时间片
	}
}
func (sl ck()和RUnlock()spinLock) Unlock() {
	atomic.StoreUint32((*uint32)(sl), 0)
}
func NewSpinLock() sync.Locker {
	var lock spinLock
	return &lock
}
```
- 互斥锁与自旋锁比较
    - 互斥锁适合用于临界区持锁时间比较长的操作
        - 临界区有IO操作
        - 临界区代码复杂或者循环量大
        - 临界区竞争非常激烈
        - 单核处理器
    
    - 至于自旋锁就主要用在临界区持锁时间非常短且CPU资源不紧张的情况下，自旋锁一般用于多核的服务器, 互斥锁开销比自旋锁高，但长时间的锁定自旋锁会占用cpu资源

## 总结
- 优先防止竞态条件发生
- channel通信代替共享内存
- 原子操作适合简单的操作更简洁高效
- 读多写少用读写锁
- 读写频繁用互斥锁
- 临界区无io操作,执行快,执行频率高,可以使用自旋锁

## 参考
[go语言圣经](https://docs.hacknode.org/gopl-zh/ch9/ch9.html)

> 借真理之力在我有生之年得以征服世界。 -- 《v字仇杀队》
