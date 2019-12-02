pop push getMin 时间复杂度为 o(1)

思路

要理解清楚题目, 在任意时候都可以getMin, 即每压入或是弹出后都能返回正确的 最小值

方法一
可以额外申请一个栈, 这个栈和功能栈一一对应， 功能栈的每一个元素对应当前的最小值
在功能栈压入元素a的时候,  与 最小值栈的栈顶b做比较， 如果 a<b, 则压入a， 否则再次压入b
功能栈弹出一个元素, 最小值栈也跟着弹出

方法二
可以看到方法一中， 最小值栈存了很多重复值， 可以想办法去掉这些重复值。
在功能栈弹出a的时候, 此时最小值栈b的栈顶b, 如果 a>b, 弹出了一个大值， 最小值没有弹出， 此时最小值栈不变， 如果a==b， 最小值弹出，b也弹出
如果 a<b， 由于压栈的顺序， 不会出现这个情况
在功能栈压入元素a的时候,  与 最小值栈的栈顶b做比较， 如果 a<b, 则压入a， 否则不处理(因为最小值没有变)

```java
public class demo1 {
    public static Stack<Integer> stack1;
    public static Stack<Integer> stack2;
    //插入数据push
    public void push(int a){
        stack1.push(a);  
        if(stack2.isEmpty()){
            stack2.push(a);
        }
        else{
            if(stack2.peek()>a){
                stack2.push(a);
            }
            // else{
            //     // 方法1与2的区别
            //     stack2.push(stack2.peek());
            // }
        }
    }
    //pop
    public  int pop(){
        int value = stack1.pop();
        if(!stack2.isEmpty() && value==stack2.peek()){
            stack2.pop();
        }
        return value;
    }

    // getMin
    public  int getMin(){
        return stack2.peek();
    }

}
```
