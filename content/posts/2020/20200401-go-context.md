
---
title: "源码阅读 - go Context"
categories: [coder]
tags: [go,源码]
date: 2020-04-01
---

## Context有什么用
当处理一个请求A，而这个请求需要在3秒内完成相应，A请求分别创建了B和C goroutine来处理逻辑，如果B或者C处理时间过长超过了3秒，那么继续执行显然是没必要且浪费资源。这时候就需要一个能终止他们的操作，而go没有提供类似 `goroutineID`这样的变量来记录goroutine状态。官方认为这样非常容易被滥用。所以Context就为此而来。

1. 利用 channel/select ，以信号的方式来通知需要停止的goroutine
2. 可以为Context记录一个key/value 来包含一些请求相关的信息

``` go
func B(ctx context.Context) error {
	for {
		select {
		case <-time.After(1 * time.Second):
			fmt.Println("hello B")
		case <-ctx.Done():
			fmt.Println("b is end")
			return ctx.Err()
		}
	}
}

func C(ctx context.Context) error {
	for {
		select {
		case <-time.After(1 * time.Second):
			fmt.Println("hello C")
		case <-ctx.Done():
			fmt.Println("b is end")
			return ctx.Err()
		}
	}
}

func main() {
	//创建一个有取消机制的context
	ctx, cancle := context.WithCancel(context.Background())
	//创建两个goroutine每秒打印一句话
	go B(ctx)
	go C(ctx)

	//5秒后发出取消信号，停止B,C
	time.Sleep(5 * time.Second)
	cancle()
	fmt.Println("end")
}

```

## 源码分析
```go
//context.go
type Context interface {
	Deadline() (deadline time.Time, ok bool)
	Done() <-chan struct{}
	Err() error
	Value(key interface{}) interface{}
}
```

context包对外提供了5个api：
```go
//返回一个有取消
func WithCancel(parent Context) (ctx Context, cancel CancelFunc)
func WithDeadline(parent Context, d time.Time) (Context, CancelFunc)
func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)

func Background() Context
func TODO() Context
```

`type emptyCtx int`
官方实现了一个默认结构，其实现的每一个api都不做任何逻辑，都返回空值。
还实现了String函数来打印实例名称。这个结构体虽然不做任何操作，但却非常重要，
`emptyCtx`实例出`background`和`todo` 对外提供Background() 和TODO()

这两个实例除了名称不同，其他都一模一样。对于此代码里有官方注释

```go
// TODO returns a non-nil, empty Context. Code should use context.TODO when
// it's unclear which Context to use or it is not yet available (because the
// surrounding function has not yet been extended to accept a Context
// parameter).
func TODO() Context {
	return todo
}
```

每一个Context都可以根据这三个api派生出n个子context。
对于派生子context，是一个树状结构，最初由根节点(比如backgroud)，不断用提供的with api创建出一个个子context，每一个子contetxt又能创建出n个子context。

当对一个context进行打印：
他的打印顺序是对String()做递归操作从根节点开始到自身将所有String()返回的字符串拼接

`Value()`
也是一个递归操作，从当前节点开始判断key是否相同，是则返回结果，否就查询父节点，直到找到结果，或查询到根节点返回nil

WithCancel/Timeout/deadline本质上都是一样的操作，都返回了一个cancelFunc，执行这个函数指针，可以发起一个停止信号，停止所有child context

timeout达到指定时间间隔执行停止信号，deadline到达某一时间点执行停止信号

timeout也是调用了deadline函数
```go
func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc) {
	return WithDeadline(parent, time.Now().Add(timeout))
}
```

关键说说WithCancel
他的执行顺序是

1. 先找到父节点中最近的那个为cancel或者timer的ctx，如果没找到则表示当前节点就是第一个cancel类型ctx，创建个goroutine来等待父节点的cancel

```go
func parentCancelCtx(parent Context) (*cancelCtx, bool) {
	for {
		switch c := parent.(type) {
		case *cancelCtx:
			return c, true
		case *timerCtx:
			return &c.cancelCtx, true
		case *valueCtx:
			parent = c.Context
		default:
			return nil, false
		}
	}
}
```

2. 如果找到了父节点，就把当前节点加入到父节点的字典里，以便父节点控制全部子节点，key是ctx地址，value是struct{}，struct{}不占字节所以这样写，也相当于set结构体。
这里加了锁，是为了保障在多个goroutine中对同一个cxt做with操作，防止race

最后无论是定时器的达到时间，还是主动取消，都是相同的操作。
```go

func (c *cancelCtx) cancel(removeFromParent bool, err error) {
	if err == nil {
		panic("context: internal error: missing cancel error")
	}
	c.mu.Lock()
	if c.err != nil {
		c.mu.Unlock()
		return // already canceled
	}
	c.err = err
	if c.done == nil {
		c.done = closedchan
	} else {
		close(c.done)
	}
	for child := range c.children {
		// NOTE: acquiring the child's lock while holding parent's lock.
		child.cancel(false, err)
	}
	c.children = nil
	c.mu.Unlock()

	if removeFromParent {
		removeChild(c.Context, c)
	}
}
```
会给done写入，这样就让所有在select Done()的地方都触发,
之后会对当前ctx全部child做同样操作，这里做了加锁操作，也是为了防止多个goroutine里对同一个ctx执行cancel

## 总结
只用cancelCtx，emptyCtx，timerCtx三个结构，简洁的代码实现了一个 goroutine之间的上下文。
对于打印和value() 操作的是当前-根节点的ctx

context利用channel当做信号对多goroutine之间发起cancel操作

```go
type timerCtx struct {
	cancelCtx
	timer *time.Timer // Under cancelCtx.mu.

	deadline time.Time
}
```