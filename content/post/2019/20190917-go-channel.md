---
title: "Go Channel"
categories: [coder]
tags: [go]
date: 2019-09-17
---

## 如何使用
- channel在<-左边 表示向channel发送数据
- channel在<-右边 表示从channel接收数据
- close(channelName) 关闭一个channel

```go
channel := make(chan string, 2)

//发送数据: 写
channel <- "struct"
//接收数据: 读
data := <-channel
fmt.Println(data)
close(channel)
```


## Channel的关闭
- 关闭一个未初始化(nil) 的 channel 会产生 panic
- 重复关闭同一个 channel 会产生 panic
- 向一个已关闭的 channel 中发送消息会产生 panic
- 从一个已关闭的 channel 中读取消息永远不会阻塞，并且会返回一个为 false 状态，可以用它来判断 channel 是否关闭,close操作是对写入的关闭,但仍然可以读取,若消息均已读出，则会读到类型的初始值

```go
func SendMessage(channel chan string) {
	go func(channel chan string) {
		channel <- "hello"
		close(channel)
		fmt.Println("channel is closed.")
	}(channel)
}

func channalFunc2() {
	channel := make(chan string, 5)
	go SendMessage(channel)

	for {
		time.Sleep(time.Second)
		chStr, ok := <-channel
		if !ok {
			fmt.Println("channel is close!!!!!!.")
			break
		} else {
			fmt.Printf("receive %s\n", chStr)
		}
	}
}
```

## 缓冲区
- make创建通道时,指定通道的大小时,称为有缓冲通道,反之无缓冲区
- 无缓冲区或者缓冲区用完,写入一次,就要等待对方读取一次,否则无法继续写入阻塞住,同理读取不出来也会阻塞住

```go
ch := make(chan int, 2)

ch <- 1
ch <- 2
// ch <- 3 //阻塞
a := <- ch
fmt.Println(a)
```

- 可以用len函数查看channel的已用大小, 用cap查看channel的缓存大小

```go
ch := make(chan int, 2)
ch <- 1
fmt.Println(len(ch)) //1
fmt.Println(cap(ch)) //2
```

## 单向通道

- 为了限制channel滥用,禁止其进行读取或者写入操作,让函数具有更高的单一原则,封装性

```go
func counter(out chan<- int) {
	for x := 0; x < 10; x++ {
		out <- x
	}
	close(out)
}

func squarer(out chan<- int, in <-chan int) {
	for v := range in {
		out <- v
	}
	close(out)
}

func printer(in <-chan int) {
	for v := range in {
		fmt.Println(v)
	}
}

func channalFunc3() {
	naturals := make(chan int)
	squares := make(chan int)
	//将读写函数分离

	//写 chan<- , 读 <-chan
	go counter(naturals)          //写入
	go squarer(squares, naturals) //将刚才写入的变成只读的,传参进去, 中间转换层
	printer(squares)              //只读
}
```

## 作用
- 同步: 依靠阻塞的特性 做多个goroutine之间的锁
```go
var (
	sema  = make(chan struct{}, 1)
	rece2 = 0
)

func raceFunc2() int {
	sema <- struct{}{}
	rece2++
	v := rece2
	<-sema
	return v
}

go raceFunc2()
go raceFunc2()
```

- 定时器
```go
fmt.Println(time.Now())
timer := time.NewTimer(time.Second * 2)
<-timer.C

fmt.Println(time.Now())
//输出: 差两秒
// 2019-06-24 16:03:34.011947 +0800 CST m=+0.000201381
// 2019-06-24 16:03:36.015244 +0800 CST m=+2.003571991
    //延迟执行
time.AfterFunc(time.Second*2, func() {
	fmt.Println(time.Now())
})
	//定时器，每隔1秒执行
ticker := time.NewTicker(time.Second)
	go func() {
	for tick := range ticker.C {
		fmt.Println("tick at", tick)
	}
}()
    
```

- 通信: Channel是goroutine之间通信的通道,用于goroutine之间发消息和接收消息

```go
type Cake struct{ state string }

func baker(cooked chan<- *Cake) {
	for {
		cake := new(Cake)
		cake.state = "cooked"
		cooked <- cake // baker never touches this cake again
	}
}

func icer(iced chan<- *Cake, cooked <-chan *Cake) {
	for cake := range cooked {
		cake.state = "iced"
		iced <- cake // icer never touches this cake again
	}
}
```

- Select多路复用(I/O多路复用，I/O就是指的我们网络I/O,多路指多个TCP连接(或多个Channel)，复用指复用一个或少量线程。串起来理解就是很多个网络I/O复用一个或少量的线程来处理这些连接)
    - 对channel的read, write,close, 超时事件等进行监听, 
    - 同时触发事件会随机执行一个
    - 阻塞在多个channel上，对多个channel的读/写事件进行监控
```go
func doWork(ch chan int) {
	for {
		select {
		case <-ch:
			fmt.Println("receive A ")
		case <-ch2:
			fmt.Println("receive B ")
		case <-time.After(2 * time.Second):
			fmt.Println("ss")
		default:
		    fmt.Println("11111")
		}
	}
}
func channalFunc5() {
	var ch chan int = make(chan int)
	go doWork(ch)
	for i := 0; i < 5; i++ {
		ch <- 1
		time.Sleep(time.Second * 1)
		ch2 <- 2
	}

	for {

	}
}
```

## 内部细节
### 数据结构
```go
type hchan struct {
	qcount   uint           // 当前队列中剩余元素个数
	dataqsiz uint           // 环形队列长度，即可以存放的元素个数
	buf      unsafe.Pointer // 环形队列指针
	elemsize uint16         // 每个元素的大小
	closed   uint32	        // 标识关闭状态
	elemtype *_type         // 元素类型
	sendx    uint           // 队列下标，指示元素写入时存放到队列中的位置
	recvx    uint           // 队列下标，指示元素从队列的该位置读出
	recvq    waitq          // 等待读消息的goroutine队列
	sendq    waitq          // 等待写消息的goroutine队列
	lock mutex              // 互斥锁，chan不允许并发读写
}

type waitq sudog{//对G的封装
    
}
```

- channel 的主要组成有：
    - 一个环形数组实现的循环队列, 用于存储消息元素
    - recvq和sendq两个链表实现的 goroutine 等待队列, 用于存储阻塞在 recv 和 send 操作上的 goroutine
    - 一个互斥锁，用于各个属性变动的同步

### 主要函数功能
- makechan: 开辟一快连续内存区域存储消息元素

```go
//伪代码
func makechan(t *chantype, size int) *hchan {
	var c *hchan
	c = new(hchan)
	c.buf = malloc(元素类型大小*size)
	c.elemsize = 元素类型大小
	c.elemtype = 元素类型
	c.dataqsiz = size
	return c
}
```
- send  chan<-
    - 如果等待接收队列recvq不为空，说明缓冲区中没有数据或者没有缓冲区，此时直接从recvq取出G,并把数据写入，最后把该G唤醒
    - 如果缓冲区中有空余位置，将数据写入缓冲区
    - 如果缓冲区中没有空余位置，将待发送数据写入G，将当前G加入sendq，进入睡眠，等待被读goroutine唤醒；

```go
//伪代码
func chansend(msg){
	if close !=0 {
		panic("close")
		return
	}
	//1.如果等待接收队列recvq不为空，说明缓冲区中没有数据或者没有缓冲区，此时
	//直接从recvq取出G,并把数据写入，最后把该G唤醒，结束发送过程
	if sg := recvq.dequeue(); sg != nil{
		sg.send(msg) //给此goroutine发消息
		sg.ready()  //唤醒
		return
	}
	//2. 跳过2说明无接收方, 如果有缓冲区且不满的话则写入到缓冲区
	if qcount < dataqsiz {
		buf.enqueue(msg)
		qcount++
		return
	}
	//3. 没空余位置或者没缓冲区, 将待发送数据写入到当前调用的G, 并加入sendq链表,进入休眠,等待被读方唤醒
	sg := get_current_g()
	sg.msg = msg
	sg.g.sleep = true
	sendq.enqueue(sg)
}
```

- recv  <-chan
    - sendq不为空 获取链表的头一个first_g
        - 缓存无数据,将first_g消息复制给当前请求的g,并激活first_g
        - 缓存有数据, 缓存队列 出列消息给当前请求的g,并将first_g数据加入缓存队列,first_g激活
    - 缓存队列有数据将数据出队 复制给当前请求的g
    - 缓存队列无数据将调用此chan的当前g加入recvq链表并设置休眠
    

```go
//伪代码
func chanrecv(){
	if sg:= sendq.dequeue(); sg != nil{
		if buff <= 0 {
			msg := sg.msg
			g := get_current_g()
			g.send(msg)
			sg.sleep = false
			
		} else {
			msg := buff.dequeue()
			g := get_current_g()
			g.send(msg)
			buff.enqueue(sg.msg)
			sg.sleep = false
		}
		
		return true
	}
    
	if qcount > 0 {
		msg := buff.dequeue()
		qcount--
		g := get_current_g()
		g.send(msg)
		return true
	}
	
	sg := get_current_g()
	sg.msg = msg
	sg.g.sleep = true
	recvq.enqueue(sg)
}
```
- close: 设置关闭符号为1,唤醒recvq和sendq的g
```go
func close(){
	if chan == nil {
		panic("close of nil channel")
		return
	}
	if close !=0 {
		panic("close of closed channel")
		return
	}
	close = 1
	for sg:=recvq.dequeue();sg!=nil{
		sg.sleep = false
	}
	for sg:=sendq.dequeue();sg!=nil{
		sg.sleep = false
	}
}
```


### demo调试
- 调试查看chan变量的结构值
```go
func run(ch chan int, a int) {
	fmt.Println("send: ", a)
	ch <- a
	fmt.Println("send ok: ", a)
}

func channelFunc1() {
	ch := make(chan int, 1)
	ch <- 1
	go run(ch, 2)
	//buff  1
	//sendq  go run
	time.Sleep(time.Second * 1)
	fmt.Println("sss: ", <-ch)
	fmt.Println("sss: ", <-ch)
	fmt.Println("sss: ", <-ch)
}

func run2(ch chan int) {
	fmt.Println(<-ch)
}

func channelFunc2() {
	ch := make(chan int, 1)
	go run2(ch)
	// recvq  go run2
	time.Sleep(time.Second * 1)
	ch <- 1
}
```

## 参考
[go语言圣经](https://books.studygolang.com/gopl-zh/)
[恋恋美食 blog](https://my.oschina.net/renhc/blog/2246871)
[draveness blog](https://draveness.me/)