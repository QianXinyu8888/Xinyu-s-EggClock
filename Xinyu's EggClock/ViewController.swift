//
//  ViewController.swift
//  Xinyu's App2
//
//  Created by Xinyu on 2025/10/16.
//

import UIKit
class ViewController: UIViewController {
//IBOutlet
    //声明Logo[xinyu]
    @IBOutlet weak var LogoLabel: UILabel!
    //声明文本框
    @IBOutlet weak var TitleLabel: UILabel!
    //定义字典
    var eggTimes=["温泉蛋🐣": 8,
                "溏心蛋🍳": 10,
                "常规蛋🥚": 18,
                "煮到烂🤮": 20]
    
    var totalTime:Int=0//该时间为对应不同蛋时的各个时间

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    //IBAction
    
    
    @IBAction func SpringEggButton(_ sender: UIButton) {
        print("温泉蛋按钮被按下")
        totalTime=eggTimes[sender.currentTitle!] ?? 0  //给totalTime赋值，即当前确定蛋的总需时间
        //TitleLabel.text="今天要煮的是\(sender.currentTitle!)\n预计 10min"   最初版本
        TitleLabel.text="今天要煮的是\(sender.currentTitle!)\n预计\(eggTimes[sender.currentTitle!] ?? 0)min"
       // print("\(eggTimes[sender.currentTitle!] ?? 0)")
        // totalTime = eggTimes[sender.currentTitle!] ?? 12
        
        //设置计时器
        timer=Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)//记得别忘了确保 timer = Timer.scheduledTimer(...)，将实例赋值给声明的 timer属性，否则timer不会正确实现语句结束。
    }
    var timer: Timer?    //使用变量前要声明，此处声明一个timer，以访问该属性。（为了控制计时器生命周期，下面有invalidate——终止计时器）
    var a = 0
    @objc func updateTimer(){
            a=a+1
            print(a)
        LogoLabel.text="\(String(a))/480s"
       //即将煮好提示
        if a==3{
            TitleLabel.text="🔥关火关火，就快煮好了！"
        }
        
        if a == 8{
            timer?.invalidate()
            timer=nil
            //print("8min倒计时结束，温泉蛋煮好啦！")
            TitleLabel.text="8min倒计时结束✅\n你的温泉蛋煮好啦！"
        }
    }
    
    
    
    @IBAction func SoftEggButton(_ sender: UIButton) {
        print("溏心蛋按钮被按下")
       // TitleLabel.text="今天要煮的是\(sender.currentTitle!)\n预计 10min"
        TitleLabel.text="今天要煮的是\(sender.currentTitle!)\n预计\(eggTimes[sender.currentTitle!] ?? 0)min"
        //设置计时器
        timer2=Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer2), userInfo: nil, repeats: true)
    }
    var timer2: Timer?    //使用变量前要声明，此处声明一个timer，以访问该属性。（为了控制计时器生命周期，下面有invalidate——终止计时器）
    var b = 0
    @objc func updateTimer2(){
            b=b+1
            print(b)
        LogoLabel.text="\(String(b))/600s"
        
        //即将煮好提示
         if b==550{
             TitleLabel.text="可以关火了，就快好了！！"
         }
        
        if b == 600{
            timer2?.invalidate()
            timer2=nil
           // print("10min倒计时结束，溏心蛋煮好啦！")
            TitleLabel.text="10min倒计时结束，溏心蛋煮好啦！"
        }
    }
    
    
    @IBAction func OrdinaryEggButton(_ sender: UIButton) {
        print("常规蛋按钮被按下")
        //TitleLabel.text="今天要煮的是\(sender.currentTitle!)\n预计 15min"
        TitleLabel.text="今天要煮的是\(sender.currentTitle!)\n预计\(eggTimes[sender.currentTitle!] ?? 0)min"
    //设置计时器
        timer3=Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer3), userInfo: nil, repeats: true)
    }
    var timer3: Timer?    //使用变量前要声明，此处声明一个timer，以访问该属性。（为了控制计时器生命周期，下面有invalidate——终止计时器）
    var c = 0
    @objc func updateTimer3(){
            c=c+1
            print(c)
        LogoLabel.text="\(String(c))/1080s"
        if c==1030{
            TitleLabel.text="可以关火了，就快好了！！"
//等待测试
        }
        
        if c == 1080{
            timer3?.invalidate()
            timer3=nil
           // print("18min倒计时结束，常规蛋煮好啦！")
            TitleLabel.text="倒计时结束，常规蛋煮好啦！"
        }
    }
    
    
    @IBAction func OverEggButton(_ sender: UIButton) {
        print("煮到烂按钮被按下")
        //TitleLabel.text="今天要\(sender.currentTitle!)\n预计 20min"
        TitleLabel.text="今天要煮的是\(sender.currentTitle!)\n预计\(eggTimes[sender.currentTitle!] ?? 0)min"
        //设置计时器
            timer4=Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer4), userInfo: nil, repeats: true)
    }
    var timer4: Timer?    //使用变量前要声明，此处声明一个timer，以访问该属性。（为了控制计时器生命周期，下面有invalidate——终止计时器）
    var d = 0
    @objc func updateTimer4(){
            d=d+1
            print(d)
        LogoLabel.text="\(String(d))/1200s"
        
        //即将煮好提示
         if d==1150{
             TitleLabel.text="可以关火了，就快好了！！"
         }
        
        if d == 1200{
            timer4?.invalidate()
            timer4=nil
           // print("20min倒计时结束，煮到烂啦！")
            TitleLabel.text="20min倒计时结束，煮到烂啦！"
        }
    }
    
    
    
    
    //声明登陆按钮
    @IBAction func LoginButton(_ sender: UIButton) {
        var username:String
        var password:String
        username = self.username.text!
        password = self.password.text!
        print("你刚刚输入的帐号为\(username)")
        print("你刚刚输入的密码为\(password)")
        if(username=="xinyu")&&(password=="12345678"){
            print("账号密码正确")
            performSegue(withIdentifier: "LoginControllerToMainController", sender: nil)
        }
            else{
            print("账号密码错误")
        }
        
        
        
        
    }
    
    //声明帐号密码文本框
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    
}

