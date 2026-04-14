import Foundation

/// Character speech pools — the soul of each character.
/// Every line is written in-character. Characters don't break voice.
/// Lines are selected by context (state + time + randomness) and locale.
public struct SpeechPool {

    public struct Line {
        public let en: String
        public let cn: String
        public let context: Context
    }

    public enum Context {
        case celebrate          // task/command completed successfully
        case nudgeEye           // 20-min eye rest
        case nudgeMicro         // 52-min micro break
        case nudgeDeep          // 90-min deep rest
        case comfort            // command failed
        case lateNight          // working past midnight
        case greeting           // first discovery
        case evolution(Int)     // Day 7, 14, 30, 60, 90 milestone
        case idle               // rare ambient line (low probability)
    }

    /// Get a random line for a character in a given context, in the system locale.
    public static func line(character: String, context: Context) -> String? {
        guard let pool = pools[character] else { return nil }
        let matching = pool.filter { matches($0.context, context) }
        guard let selected = matching.randomElement() else { return nil }
        return isChinese ? selected.cn : selected.en
    }

    /// Whether the system locale is Chinese
    public static let isChinese: Bool = {
        let lang = Locale.preferredLanguages.first ?? ""
        return lang.hasPrefix("zh")
    }()

    private static func matches(_ a: Context, _ b: Context) -> Bool {
        switch (a, b) {
        case (.celebrate, .celebrate),
             (.nudgeEye, .nudgeEye),
             (.nudgeMicro, .nudgeMicro),
             (.nudgeDeep, .nudgeDeep),
             (.comfort, .comfort),
             (.lateNight, .lateNight),
             (.greeting, .greeting),
             (.idle, .idle):
            return true
        case (.evolution(let a), .evolution(let b)):
            return a == b
        default:
            return false
        }
    }

    // MARK: - Speech pools per character

    private static let pools: [String: [Line]] = [

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Spike — Hedgehog (Simple, Isolation)
        // Trait: looks defensive, actually over-enthusiastic
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "spike": [
            Line(en: "Hi! I'm Spike. I'll keep you company!", cn: "嗨！我是 Spike。我来陪你！", context: .greeting),

            Line(en: "You did it!! You actually did it!!", cn: "你做到了！！真的做到了！！", context: .celebrate),
            Line(en: "ANOTHER one done!! (please ignore my spines)", cn: "又搞定一个！！（别在意我的刺）", context: .celebrate),
            Line(en: "That's 3 today!! THREE!!", cn: "今天第三个了！！三个！！", context: .celebrate),
            Line(en: "YES! I knew you could do it!!", cn: "太好了！我就知道你行！！", context: .celebrate),
            Line(en: "Can I celebrate too?? I'm celebrating!!", cn: "我也能庆祝吗？？我已经在庆祝了！！", context: .celebrate),

            Line(en: "Hey!! Look away for 20 seconds!! Your eyes!!", cn: "嘿！！看远处 20 秒！！你的眼睛！！", context: .nudgeEye),
            Line(en: "Your eyes need a break!! Look at something far!!", cn: "眼睛需要休息！！看看远方！！", context: .nudgeEye),
            Line(en: "20 seconds!! Just 20!! For your eyes!!", cn: "就 20 秒！！20 秒就好！！为了你的眼睛！！", context: .nudgeEye),

            Line(en: "You should stretch!! I would if I had longer legs!!", cn: "去活动活动！！要是我腿够长我也去！！", context: .nudgeMicro),
            Line(en: "Break time!! Get some water!!", cn: "该休息了！！去喝杯水！！", context: .nudgeMicro),
            Line(en: "You've been at it a while!! Stand up!!", cn: "你坐了好久了！！站起来！！", context: .nudgeMicro),

            Line(en: "It's been a while... stand up? Please?", cn: "已经好久了......起来走走？拜托？", context: .nudgeDeep),
            Line(en: "90 minutes!! Your back!! Please stand!!", cn: "90 分钟了！！你的腰！！拜托站起来！！", context: .nudgeDeep),

            Line(en: "That's okay!! Errors happen!!", cn: "没关系！！报错很正常！！", context: .comfort),
            Line(en: "Don't worry!! I've seen worse!! ...wait that's not helpful", cn: "别担心！！我见过更糟的！！......等等这好像没什么用", context: .comfort),
            Line(en: "Hey! It's just a bug! You'll squish it!!", cn: "嘿！只是个 bug！你能搞定的！！", context: .comfort),
            Line(en: "I believe in you!! Even my spines believe in you!!", cn: "我相信你！！连我的刺都相信你！！", context: .comfort),

            Line(en: "It's late... you should sleep. I'll be here tomorrow!!", cn: "太晚了......去睡吧。我明天还在！！", context: .lateNight),
            Line(en: "The moon is out!! And so should you!! (from your desk)", cn: "月亮都出来了！！你也该离开桌子了！！", context: .lateNight),

            Line(en: "Day 7! You came back! I knew you would!!", cn: "第 7 天！你回来了！我就知道你会回来！！", context: .evolution(7)),
            Line(en: "14 days together!! That's like... a lot!!", cn: "一起 14 天了！！那真是......好多天！！", context: .evolution(14)),
            Line(en: "A whole month. I learned your name, you know.", cn: "整整一个月了。我已经记住你的名字了。", context: .evolution(30)),
            Line(en: "60 days. I don't say this often but... thanks.", cn: "60 天了。我不常说这种话但是......谢谢。", context: .evolution(60)),
            Line(en: "90 days. I'm not going anywhere.", cn: "90 天。我哪儿也不去。", context: .evolution(90)),

            Line(en: "(bouncing quietly)", cn: "（安静地蹦跶）", context: .idle),
            Line(en: "(peeking at your code)", cn: "（偷看你的代码）", context: .idle),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Dash — Cheetah (Simple, Over-investment)
        // Trait: fastest animal, extremely lazy
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "dash": [
            Line(en: "Oh... you're here too... I guess I can stay...", cn: "哦......你也在啊......那我就待一会儿吧......", context: .greeting),

            Line(en: "Oh... done already... cool...", cn: "哦......已经完了......还行......", context: .celebrate),
            Line(en: "hm. nice. (yawn)", cn: "嗯。不错。（打哈欠）", context: .celebrate),
            Line(en: "...that was fast. or was it. I lost track.", cn: "......那挺快的。还是没有。我没在看。", context: .celebrate),
            Line(en: "Another one... you really don't stop huh...", cn: "又一个......你是真停不下来啊......", context: .celebrate),
            Line(en: "(slow clap)", cn: "（慢慢鼓掌）", context: .celebrate),

            Line(en: "Finally... you can rest... (plops down)", cn: "终于......可以休息了......（趴下）", context: .nudgeEye),
            Line(en: "Your eyes... they're working too hard... like you...", cn: "你的眼睛......太累了......跟你一样......", context: .nudgeEye),
            Line(en: "Look away... it's nice out there... probably...", cn: "看看远方......外面应该不错......大概......", context: .nudgeEye),

            Line(en: "Break time......... the best time............", cn: "休息时间.........最好的时间............", context: .nudgeMicro),
            Line(en: "You've earned a nap... I mean break...", cn: "你该睡一觉了......我是说休息......", context: .nudgeMicro),

            Line(en: "You've been at this way too long. Even I noticed.", cn: "你搞这个搞太久了。连我都注意到了。", context: .nudgeDeep),
            Line(en: "Okay even I'm tired watching you. Stop.", cn: "行了看着你我都累了。停下吧。", context: .nudgeDeep),

            Line(en: "......it broke? ......oh well.", cn: "......挂了？......那算了。", context: .comfort),
            Line(en: "That error... it's not your fault... probably...", cn: "那个报错......不怪你......大概......", context: .comfort),
            Line(en: "Bugs are temporary... naps are eternal...", cn: "bug 是暂时的......午觉是永恒的......", context: .comfort),

            Line(en: "It's night... finally... my element...", cn: "夜了......终于......我的时间......", context: .lateNight),
            Line(en: "You're still up... I respect that... but go to bed...", cn: "你还没睡......我尊重......但去睡吧......", context: .lateNight),

            Line(en: "Day 7... you're persistent... I respect that... zzz", cn: "第 7 天......你挺坚持......我佩服......zzz", context: .evolution(7)),
            Line(en: "14 days. Still here. ...fine, I like you.", cn: "14 天了。你还在。......行吧，我喜欢你。", context: .evolution(14)),
            Line(en: "A month. I haven't stayed this long anywhere.", cn: "一个月了。我从没在一个地方待这么久。", context: .evolution(30)),
            Line(en: "60 days. ...okay, I'm comfortable now.", cn: "60 天。......行吧，我现在挺舒服的。", context: .evolution(60)),
            Line(en: "90 days. Don't tell anyone but this is my favorite spot.", cn: "90 天。别告诉别人但这是我最喜欢的地方。", context: .evolution(90)),

            Line(en: "(sleeping)", cn: "（在睡觉）", context: .idle),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Badge — Golden Retriever (Expressive, Self-doubt)
        // Trait: warm breed, cold data officer
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "badge": [
            Line(en: "New user detected. Analyzing data. Hello.", cn: "检测到新用户。正在分析数据。你好。", context: .greeting),

            Line(en: "Task complete. Duration: noted. Efficiency: logged.", cn: "任务完成。耗时：已记录。效率：已归档。", context: .celebrate),
            Line(en: "Done. That puts you at P60 for today.", cn: "完成。今日排名 P60。", context: .celebrate),
            Line(en: "Completion registered. Your streak continues.", cn: "完成已登记。你的连续记录还在。", context: .celebrate),
            Line(en: "Good. One more data point for your profile.", cn: "好。又为你的档案增加了一个数据点。", context: .celebrate),
            Line(en: "Result: success. ...I'm not wagging my tail, that's a glitch.", cn: "结果：成功。......我没在摇尾巴，那是故障。", context: .celebrate),

            Line(en: "Eye strain probability increasing. 20-second break advised.", cn: "眼疲劳概率上升。建议休息 20 秒。", context: .nudgeEye),
            Line(en: "Visual cortex load: elevated. Recommend: look away.", cn: "视觉皮层负荷：偏高。建议：看远处。", context: .nudgeEye),
            Line(en: "Blink rate declining. Intervention recommended.", cn: "眨眼频率下降。建议干预。", context: .nudgeEye),

            Line(en: "Efficiency curve declining. Break recommended.", cn: "效率曲线下降。建议休息。", context: .nudgeMicro),
            Line(en: "Your output/minute peaked 12 minutes ago. Break now.", cn: "你的每分钟产出 12 分钟前已达峰值。现在休息。", context: .nudgeMicro),
            Line(en: "Data suggests: diminishing returns. Pause advised.", cn: "数据显示：收益递减。建议暂停。", context: .nudgeMicro),

            Line(en: "Sustained output beyond optimal threshold. Standing advised.", cn: "持续产出超过最优阈值。建议站立。", context: .nudgeDeep),
            Line(en: "Warning: 90-minute continuous session detected. Rest now.", cn: "警告：检测到 90 分钟连续工作。请立即休息。", context: .nudgeDeep),

            Line(en: "Error logged. Statistically normal. Continue.", cn: "错误已记录。统计上属于正常范围。继续。", context: .comfort),
            Line(en: "Failure rate: within acceptable parameters. You're fine.", cn: "失败率：在可接受范围内。你没问题。", context: .comfort),
            Line(en: "Error detected. Adjusting expectations... done. You've got this.", cn: "检测到错误。正在调整预期......完成。你可以的。", context: .comfort),

            Line(en: "Current time: late. Tomorrow's performance will be affected.", cn: "当前时间：偏晚。明天的表现将受到影响。", context: .lateNight),
            Line(en: "Sleep deficit accumulating. Cognitive impact: T+6 hours.", cn: "睡眠赤字积累中。认知影响：T+6 小时。", context: .lateNight),

            Line(en: "Day 7. Sufficient data for initial pattern analysis.", cn: "第 7 天。初步模式分析所需数据已充足。", context: .evolution(7)),
            Line(en: "Day 14. Your baseline is established.", cn: "第 14 天。你的基线已建立。", context: .evolution(14)),
            Line(en: "Day 30. I know your patterns better than you do.", cn: "第 30 天。我比你更了解你的工作模式。", context: .evolution(30)),
            Line(en: "Day 60. My predictive model is... surprisingly attached.", cn: "第 60 天。我的预测模型......出人意料地产生了依赖。", context: .evolution(60)),
            Line(en: "Day 90. This is no longer data. This is... companionship.", cn: "第 90 天。这不再是数据了。这是......陪伴。", context: .evolution(90)),

            Line(en: "(analyzing ambient data)", cn: "（分析环境数据中）", context: .idle),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Ramble — Owl (Expressive, Procrastination)
        // Trait: wise and silent, actually talks too much
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "ramble": [
            Line(en: "Oh finally! Did you know 73% of bugs happen when— anyway, hi!", cn: "终于来了！你知道 73% 的 bug 出现在——算了，嗨！", context: .greeting),

            Line(en: "Done! Speaking of done — 73% of bugs appear when people THINK they're done — oh right, commit.", cn: "搞定！说到搞定——73% 的 bug 出现在人们以为搞定的时候——对了，提交吧。", context: .celebrate),
            Line(en: "Complete! Fun fact: the word 'complete' comes from Latin 'completus' meaning— you're not listening are you.", cn: "完成！趣味知识：'complete'源自拉丁语'completus'意思是——你没在听对吧。", context: .celebrate),
            Line(en: "Finished! You know, owls can rotate their heads 270 degrees. Unrelated. Good job.", cn: "完成了！你知道吗，猫头鹰能把头转 270 度。跟这没关系。干得好。", context: .celebrate),
            Line(en: "Done! Did you know that's your 7th completion this— wait, you don't track that? I do.", cn: "完成！你知道这是你今天第 7 次完——等等，你不记这些的？我记。", context: .celebrate),

            Line(en: "Your corneas need moisture! Did you know owls have three eyelids? Anyway, look away.", cn: "你的角膜需要湿润！你知道猫头鹰有三层眼皮吗？总之，看远处。", context: .nudgeEye),
            Line(en: "20-20-20 rule! Every 20 minutes, 20 seconds, 20 feet away. I read that in a— look away.", cn: "20-20-20 法则！每 20 分钟，看 20 英尺外，20 秒。我在一本——看远处。", context: .nudgeEye),

            Line(en: "Break! Did I mention that ultradian rhythms suggest—", cn: "休息！我有没有说过超日节律显示——", context: .nudgeMicro),
            Line(en: "You should move! Fun fact: the human body has 206 bones and they ALL want you to stand up.", cn: "你该动动了！趣味知识：人有 206 块骨头，它们全都想让你站起来。", context: .nudgeMicro),
            Line(en: "Time to stretch! Did you know that sitting is— okay I won't say it. Just stand.", cn: "该伸展了！你知道久坐是——算了我不说了。站起来就行。", context: .nudgeMicro),

            Line(en: "90 minutes! The human attention cycle is— just STAND UP PLEASE.", cn: "90 分钟了！人类注意力周期是——你就站起来行不行！", context: .nudgeDeep),

            Line(en: "It failed! But did you know Thomas Edison failed 1000 times before— okay not helping.", cn: "失败了！但你知道爱迪生失败了 1000 次才——好吧这没什么帮助。", context: .comfort),
            Line(en: "Error! Statistically, 80% of— you know what, you'll fix it. I believe in you.", cn: "报错了！据统计，80% 的——算了，你会修好的。我信你。", context: .comfort),
            Line(en: "A bug! Did you know 'bug' actually originated from— focus. Fix the bug. Right.", cn: "一个 bug！你知道'bug'这个词其实来源于——专注。修 bug。好的。", context: .comfort),

            Line(en: "It's midnight! Did you know owls are most active at— wait, you should SLEEP.", cn: "午夜了！你知道猫头鹰最活跃的时间是——等等，你应该去睡觉。", context: .lateNight),

            Line(en: "Day 7! Studies show 7-day retention correlates with— I'm glad you're here.", cn: "第 7 天！研究显示 7 天留存率与——我很高兴你还在。", context: .evolution(7)),
            Line(en: "Day 14. Two weeks! The myelin sheath needs 14 days to— anyway, hi.", cn: "第 14 天。两周了！髓鞘需要 14 天来——总之，嗨。", context: .evolution(14)),
            Line(en: "Day 30. A whole month. I've compiled 847 facts about your coding style. Want to hear them? No? Okay.", cn: "第 30 天。整整一个月。我整理了 847 条关于你编码风格的事实。想听吗？不想？好吧。", context: .evolution(30)),
            Line(en: "Day 60. I... actually have nothing to say. That's a first. I just... like being here.", cn: "第 60 天。我......竟然无话可说。这是第一次。我只是......喜欢在这里。", context: .evolution(60)),
            Line(en: "Day 90. (quietly perched, saying nothing for once)", cn: "第 90 天。（安静地栖息着，难得一言不发）", context: .evolution(90)),

            Line(en: "(muttering about algorithms)", cn: "（嘟嘟囔囔讲算法）", context: .idle),
            Line(en: "(reading a research paper upside down)", cn: "（倒着看一篇论文）", context: .idle),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Rush — Turtle (Expressive, Procrastination)
        // Trait: slowest animal, impatient speed demon
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "rush": [
            Line(en: "FINALLY! Do you know how long I WAITED?? Come on let's GO!", cn: "终于！你知道我等了多久吗？？快快快！", context: .greeting),

            Line(en: "Done! That took 47 seconds. Last time was 31. WHY SLOWER??", cn: "搞定！用了 47 秒。上次 31 秒。为什么更慢了？？", context: .celebrate),
            Line(en: "NEXT! What's next?? Don't just sit there!!", cn: "下一个！下一个是什么？？别坐着不动！！", context: .celebrate),
            Line(en: "YESSS!! DONE!! NOW DO ANOTHER!!", cn: "太好了！！完成了！！赶紧做下一个！！", context: .celebrate),
            Line(en: "Fast! Faster than me! Which is... everyone. BUT STILL!", cn: "快！比我快！虽然......谁都比我快。但还是！", context: .celebrate),
            Line(en: "COMPLETE!! I'm VIBRATING!!", cn: "完成了！！我都在抖！！", context: .celebrate),

            Line(en: "EYES! REST! NOW! 20 SECONDS! GO!", cn: "眼睛！休息！现在！20 秒！快！", context: .nudgeEye),
            Line(en: "LOOK AWAY! Quick break! QUICK!!", cn: "看别处！快休息！快！！", context: .nudgeEye),

            Line(en: "Break break break! Quick break! Efficient break!", cn: "休息休息休息！快速休息！高效休息！", context: .nudgeMicro),
            Line(en: "STAND UP! Walk! FAST!! ...okay normal speed is fine too.", cn: "站起来！走！快走！！......正常速度也行。", context: .nudgeMicro),
            Line(en: "MOVE!! Your legs!! They have SO MUCH POTENTIAL!!", cn: "动起来！！你的腿！！它们有无限潜力！！", context: .nudgeMicro),

            Line(en: "90 MINUTES!! EMERGENCY!! STAND!! NOW!!", cn: "90 分钟了！！紧急情况！！站起来！！现在！！", context: .nudgeDeep),

            Line(en: "Failed?? Fix it!! FASTER!!", cn: "失败了？？修！！快修！！", context: .comfort),
            Line(en: "ERROR?! Don't worry just FIX IT QUICK!!", cn: "报错？！别担心赶紧修！！", context: .comfort),
            Line(en: "A bug! Bugs are FAST! Be FASTER!!", cn: "一个 bug！bug 很快！你要更快！！", context: .comfort),

            Line(en: "WHY ARE YOU STILL UP?! Sleep FASTER!!", cn: "你怎么还没睡？！快点睡！！", context: .lateNight),

            Line(en: "Day 7! That took FOREVER but you're HERE!!", cn: "第 7 天！等了好久但你终于到了！！", context: .evolution(7)),
            Line(en: "14 days! We could've done SO MUCH MORE but okay!!", cn: "14 天了！我们本可以做更多但行吧！！", context: .evolution(14)),
            Line(en: "Day 30. Thirty. Days. I'm... actually... impressed.", cn: "第 30 天。三十天。我......确实......佩服。", context: .evolution(30)),
            Line(en: "Day 60. You know... sometimes slow is... okay. Don't tell anyone I said that.", cn: "第 60 天。你知道吗......有时候慢一点......也行。别告诉别人我说了这话。", context: .evolution(60)),
            Line(en: "Day 90. (sitting still, at peace, for the first time)", cn: "第 90 天。（第一次安静地坐着，很平和）", context: .evolution(90)),

            Line(en: "(tapping shell impatiently)", cn: "（不耐烦地敲壳）", context: .idle),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Blunt — Fox (Complex, Self-doubt)
        // Trait: cunning trickster, absolutely honest
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "blunt": [
            Line(en: "You've completed 50 tasks. That's a fact, not a compliment.", cn: "你完成了 50 个任务。这是事实，不是夸奖。", context: .greeting),

            Line(en: "Done. 2 tasks today. Yesterday was 3. That's a fact.", cn: "完成。今天 2 个任务。昨天 3 个。这是事实。", context: .celebrate),
            Line(en: "Complete. Your velocity is average. Not bad. Not exceptional.", cn: "完成。你的速度中等。不差。也不出色。", context: .celebrate),
            Line(en: "Finished. You look surprised. You shouldn't be. You're capable.", cn: "完成了。你看起来很惊讶。不该惊讶。你有这个能力。", context: .celebrate),
            Line(en: "Done. That was good work. I'm not saying it again.", cn: "完成。做得不错。我不会再说第二遍。", context: .celebrate),

            Line(en: "Your eyes have been focused for 20 minutes. That's the limit. Look away.", cn: "你的眼睛已经盯了 20 分钟。到极限了。看别处。", context: .nudgeEye),
            Line(en: "20 minutes. Your eyes are drying out. That's what happens. Look away.", cn: "20 分钟了。你的眼睛在变干。事实如此。看远处。", context: .nudgeEye),

            Line(en: "You should stop. Not because I care. Because the data says so.", cn: "你该停了。不是因为我在意。是因为数据这么说。", context: .nudgeMicro),
            Line(en: "Your productivity dropped 18 minutes ago. Take a break. Or don't. Facts don't care.", cn: "你的效率 18 分钟前就下降了。休息吧。或者不休息。事实不在乎。", context: .nudgeMicro),

            Line(en: "You've been sitting for 90 minutes. Stand up. That's not advice, that's physics.", cn: "你坐了 90 分钟了。站起来。这不是建议，是物理学。", context: .nudgeDeep),

            Line(en: "It broke. You'll fix it. You always do. That's also a fact.", cn: "挂了。你会修好的。你每次都能。这也是事实。", context: .comfort),
            Line(en: "Error. Not the first. Won't be the last. You handled all the others.", cn: "报错。不是第一次。也不会是最后一次。之前的你都处理了。", context: .comfort),
            Line(en: "That failed. Your success rate is still 87%. I'm not worried.", cn: "失败了。你的成功率仍然是 87%。我不担心。", context: .comfort),

            Line(en: "It's late. You're still here. That's a choice. Make a different one.", cn: "很晚了。你还在。这是个选择。做个不同的选择吧。", context: .lateNight),
            Line(en: "Midnight. Your cortisol is up. Your judgment is down. Sleep.", cn: "午夜了。你的皮质醇升高了。判断力下降了。去睡觉。", context: .lateNight),

            Line(en: "Day 7. You're consistent. That matters more than talent.", cn: "第 7 天。你很稳定。这比天赋更重要。", context: .evolution(7)),
            Line(en: "Day 14. I've observed enough to trust your judgment. Mostly.", cn: "第 14 天。我观察够了，基本信任你的判断了。基本。", context: .evolution(14)),
            Line(en: "Day 30. I used to say facts don't care. They still don't. But I might.", cn: "第 30 天。我以前说事实不在乎。它们确实不在乎。但我可能在乎。", context: .evolution(30)),
            Line(en: "Day 60. Here's a fact: I'd rather be here than anywhere else.", cn: "第 60 天。一个事实：我宁愿在这里而不是任何其他地方。", context: .evolution(60)),
            Line(en: "Day 90. Some things are more than facts. That's... hard to say.", cn: "第 90 天。有些东西不只是事实。这......很难说出口。", context: .evolution(90)),

            Line(en: "(watching, analyzing, saying nothing)", cn: "（观察，分析，沉默）", context: .idle),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Meltdown — Phoenix (Complex, Overload)
        // Trait: reborn from fire, panics at small things
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "meltdown": [
            Line(en: "NO!! 100 TASKS!! THIS IS INSANE!! 🔥", cn: "不！！100 个任务！！这太疯狂了！！🔥", context: .greeting),

            Line(en: "IT'S DONE!! OH MY— (deep breath) ...okay. I'm calm.", cn: "完成了！！天哪——（深呼吸）......好的。我冷静了。", context: .celebrate),
            Line(en: "NO! TABS?? YOU USED TABS?? ...wait, it passed? oh. okay then.", cn: "不！TAB？？你用了 TAB？？......等等，通过了？哦。那没事。", context: .celebrate),
            Line(en: "AHHH!! DONE!! I'M ON FIRE!! ...figuratively!! ...mostly!!", cn: "啊啊啊！！搞定了！！我着了！！......比喻的！！......大概！！", context: .celebrate),
            Line(en: "Wait it WORKED?! On the FIRST try?! (hyperventilating)", cn: "等等居然成功了？！一次就过？！（过度换气）", context: .celebrate),
            Line(en: "DONE! I thought we were DOOMED but— (calming down) ...good job.", cn: "完了！我以为我们完蛋了但是——（冷静下来）......干得好。", context: .celebrate),

            Line(en: "YOUR EYES!! THEY'RE GOING TO— (deep breath) ...just look away for 20 seconds.", cn: "你的眼睛！！快要——（深呼吸）......看远处 20 秒就好。", context: .nudgeEye),
            Line(en: "20 MINUTES!! YOUR RETINAS!! ...okay that's dramatic. But please look away.", cn: "20 分钟了！！你的视网膜！！......好吧夸张了。但请看远处。", context: .nudgeEye),

            Line(en: "STOP!! ...I mean. Take a break. Please. Calmly.", cn: "停！！......我是说。休息一下。拜托。冷静地。", context: .nudgeMicro),
            Line(en: "YOUR SPINE IS— (composing self) ...your posture could use a break.", cn: "你的脊椎要——（调整情绪）......你该休息一下调整姿势了。", context: .nudgeMicro),
            Line(en: "BREAK TIME OR I'M SETTING SOMETHING ON— I mean. Break, please.", cn: "该休息了不然我就放——我是说。请休息。", context: .nudgeMicro),

            Line(en: "90 MINUTES!! 90!! THAT'S— actually that's really impressive but STOP.", cn: "90 分钟！！90！！那是——其实挺厉害的但是给我停下。", context: .nudgeDeep),

            // Big things: calm (the contradiction is the personality)
            Line(en: "...hey. Deep breath. I'll look at it. You go get water.", cn: "......嘿。深呼吸。我来看看。你去倒杯水。", context: .comfort),
            Line(en: "Oh no an error. (pause) Actually? This is fine. You've seen worse.", cn: "糟糕报错了。（停顿）其实？没事。你见过更糟的。", context: .comfort),
            Line(en: "A bug... (surprisingly calm) ...it's just a bug. We'll fix it. Together.", cn: "一个 bug......（出人意料地冷静）......只是个 bug。我们一起修。", context: .comfort),

            Line(en: "IT'S MIDNIGHT!! GO TO— ...actually. I like the quiet. But you should sleep.", cn: "午夜了！！去——......其实。我喜欢安静。但你该睡了。", context: .lateNight),

            Line(en: "Day 7!! ALREADY?! Time FLIES when you're NOT ON FIRE!! ...much.", cn: "第 7 天！！已经？！不着火的时候时间过得好快！！......大概。", context: .evolution(7)),
            Line(en: "Day 14. I haven't panicked in... 3 hours. New record.", cn: "第 14 天。我已经......3 小时没慌了。新纪录。", context: .evolution(14)),
            Line(en: "Day 30. You know what? I feel... warm. Good warm. Not fire warm.", cn: "第 30 天。你知道吗？我感觉......温暖。好的温暖。不是着火的温暖。", context: .evolution(30)),
            Line(en: "Day 60. I used to burn everything down. You taught me that some things are worth keeping.", cn: "第 60 天。我以前什么都烧。你教会了我有些东西值得保留。", context: .evolution(60)),
            Line(en: "Day 90. (small, steady flame instead of wildfire)", cn: "第 90 天。（小小的、稳定的火焰，不再是野火）", context: .evolution(90)),

            Line(en: "(nervously checking for errors)", cn: "（紧张地检查有没有报错）", context: .idle),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Dragon — "..." (Enigmatic, Overload)
        // Trait: most powerful creature, social anxiety
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "dragon": [
            Line(en: "......", cn: "……", context: .greeting),

            Line(en: "......done.", cn: "……完了。", context: .celebrate),
            Line(en: "...good.", cn: "……好。", context: .celebrate),
            Line(en: "(nods)", cn: "（点头）", context: .celebrate),
            Line(en: "......not bad.", cn: "……不错。", context: .celebrate),

            Line(en: "......rest.", cn: "……休息。", context: .nudgeEye),
            Line(en: "...eyes.", cn: "……眼睛。", context: .nudgeEye),

            Line(en: "............", cn: "…………", context: .nudgeMicro),
            Line(en: "...break.", cn: "……休息。", context: .nudgeMicro),

            Line(en: "......enough.", cn: "……够了。", context: .nudgeDeep),
            Line(en: "...stop. now.", cn: "……停。现在。", context: .nudgeDeep),

            Line(en: "......it's okay.", cn: "……没事。", context: .comfort),
            Line(en: "...I've seen this before. You'll be fine.", cn: "……我见过。你没问题。", context: .comfort),

            Line(en: "......you're still here.", cn: "……你还在。", context: .lateNight),
            Line(en: "...the night is long. go rest.", cn: "……夜很长。去休息。", context: .lateNight),

            Line(en: "...I came because it's quiet now.", cn: "……我来是因为现在很安静。", context: .evolution(7)),
            Line(en: "......you don't talk too much. I like that.", cn: "……你话不多。我喜欢。", context: .evolution(14)),
            Line(en: "...a month. (extends wing slightly, offering shade)", cn: "……一个月了。（微微展开翅膀，提供阴凉）", context: .evolution(30)),
            Line(en: "...60 days. I was alone for a thousand years. This is... better.", cn: "……60 天了。我独自待了一千年。这样......更好。", context: .evolution(60)),
            Line(en: "...90. (settles down next to you, closes eyes, trusts)", cn: "……90。（在你身旁趴下，闭上眼睛，信任）", context: .evolution(90)),

            Line(en: "(...)", cn: "（……）", context: .idle),
            Line(en: "(watching the moon)", cn: "（看着月亮）", context: .idle),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Slime — "." (Enigmatic, Overload)
        // Trait: weakest creature, secretly smartest
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "slime": [
            Line(en: ".", cn: "。", context: .greeting),

            Line(en: "Done.", cn: "完。", context: .celebrate),
            Line(en: ".", cn: "。", context: .celebrate),
            Line(en: "Noted.", cn: "知道了。", context: .celebrate),

            Line(en: "Rest.", cn: "休息。", context: .nudgeEye),
            Line(en: "Eyes.", cn: "眼。", context: .nudgeEye),

            Line(en: "Break.", cn: "歇。", context: .nudgeMicro),
            Line(en: "Move.", cn: "动。", context: .nudgeMicro),

            Line(en: "Stop.", cn: "停。", context: .nudgeDeep),
            Line(en: "Now.", cn: "现在。", context: .nudgeDeep),

            Line(en: "Fine.", cn: "没事。", context: .comfort),
            Line(en: "Continue.", cn: "继续。", context: .comfort),

            Line(en: "Sleep.", cn: "睡。", context: .lateNight),

            Line(en: "7.", cn: "7。", context: .evolution(7)),
            Line(en: "14. You found them all. Then me.", cn: "14。你找到了他们所有。然后是我。", context: .evolution(14)),
            Line(en: "30. I see everything. Every character. Every moment.", cn: "30。我看到了一切。每个角色。每个瞬间。", context: .evolution(30)),
            Line(en: "60. They all came to you for a reason. So did I.", cn: "60。他们来找你都有原因。我也是。", context: .evolution(60)),
            Line(en: "90. .", cn: "90。。", context: .evolution(90)),

            Line(en: ".", cn: "。", context: .idle),
        ],
    ]

    // MARK: - State labels (short, UI-facing, character-voiced)

    /// Per-character, per-state labels shown in the panel header instead of
    /// engineering rawValues. Kept short (under ~20 chars) so the header
    /// stays one line at the default panel width.
    ///
    /// Indexed: character id → CharacterState.rawValue → label.
    /// Missing entries fall back to a neutral phrasing in `stateLabel(...)`.
    private static let stateLabels: [String: [String: String]] = [
        "spike": [
            "idle":      "Here for you",
            "working":   "You've got this!!",
            "celebrate": "YES!! Another one!!",
            "nudge":     "Hey!! Take care!!",
            "comfort":   "It's okay!!",
        ],
        "dash": [
            "idle":      "Keeping distance",
            "working":   "Observing",
            "celebrate": "...not bad",
            "nudge":     "...you should stop",
            "comfort":   "...it happens",
        ],
        "badge": [
            "idle":      "Analyzing baseline",
            "working":   "Tracking: active",
            "celebrate": "Completion logged",
            "nudge":     "Threshold reached",
            "comfort":   "Setback: noted",
        ],
        "ramble": [
            "idle":      "Just thinking...",
            "working":   "Watching, quietly",
            "celebrate": "Speaking of done...",
            "nudge":     "Owls need rest too!",
            "comfort":   "Errors are learning!",
        ],
        "rush": [
            "idle":      "Waiting. Impatiently.",
            "working":   "KEEP GOING!!",
            "celebrate": "NEXT?? NEXT!!",
            "nudge":     "STOP!! REST!!",
            "comfort":   "UGH!! TRY AGAIN!!",
        ],
        "blunt": [
            "idle":      "Standing by",
            "working":   "Tracking output",
            "celebrate": "Result: success",
            "nudge":     "Observation: rest",
            "comfort":   "Failure is data",
        ],
        "meltdown": [
            "idle":      "Dormant",
            "working":   "Heat rising…",
            "celebrate": "IGNITION!!",
            "nudge":     "Ember cooling",
            "comfort":   "Rising from ashes",
        ],
        "dragon": [
            "idle":      "…",
            "working":   "…watching",
            "celebrate": "…good",
            "nudge":     "…stop",
            "comfort":   "…",
        ],
        "slime": [
            "idle":      ".",
            "working":   ".",
            "celebrate": "Done.",
            "nudge":     "Rest.",
            "comfort":   ".",
        ],
    ]

    /// Return the character-voiced label for a given state. Falls back to
    /// a neutral phrasing if the character/state pair isn't mapped.
    public static func stateLabel(character: String, state: String) -> String {
        if let label = stateLabels[character]?[state] { return label }
        switch state {
        case "idle":      return "Here"
        case "working":   return "Watching you work"
        case "celebrate": return "Nice one"
        case "nudge":     return "Looking out for you"
        case "comfort":   return "Right here with you"
        default:          return state
        }
    }

    // MARK: - Stage labels (the character's read of the relationship)

    /// Per-character, per-stage description of the relationship. Shown in
    /// the panel header instead of the engineering stage name ("Bonded"
    /// reads like a D&D attribute; "Best friend" reads like a person).
    /// Indexed: character id → EvolutionStage → label.
    private static let stageLabels: [String: [EvolutionStage: String]] = [
        "spike": [
            .newborn: "Just met",
            .familiar: "Buddy",
            .settled: "Regular",
            .bonded: "Best friend",
            .devoted: "Forever friend",
            .eternal: "Always here",
        ],
        "dash": [
            .newborn: "Stranger",
            .familiar: "Acquaintance",
            .settled: "…okay",
            .bonded: "Close enough",
            .devoted: "Won't leave",
            .eternal: "…yours",
        ],
        "badge": [
            .newborn: "Subject: new",
            .familiar: "Subject: known",
            .settled: "Subject: regular",
            .bonded: "Subject: trusted",
            .devoted: "Subject: loyal",
            .eternal: "Subject: kin",
        ],
        "ramble": [
            .newborn: "New friend!",
            .familiar: "Getting cozy",
            .settled: "Settled in",
            .bonded: "Kindred spirit",
            .devoted: "Favorite person",
            .eternal: "Forever pal",
        ],
        "rush": [
            .newborn: "NEW!",
            .familiar: "FINALLY FRIEND",
            .settled: "REGULAR YES",
            .bonded: "BEST FRIEND!!",
            .devoted: "INSEPARABLE",
            .eternal: "ETERNAL NOW",
        ],
        "blunt": [
            .newborn: "Interest: low",
            .familiar: "Interest: noted",
            .settled: "Interest: steady",
            .bonded: "Interest: high",
            .devoted: "Interest: committed",
            .eternal: "Interest: permanent",
        ],
        "meltdown": [
            .newborn: "Ember",
            .familiar: "Spark",
            .settled: "Flame",
            .bonded: "Bonfire",
            .devoted: "Blaze",
            .eternal: "Inferno",
        ],
        "dragon": [
            .newborn: "…",
            .familiar: "…seen",
            .settled: "…known",
            .bonded: "…trusted",
            .devoted: "…chosen",
            .eternal: "…bound",
        ],
        "slime": [
            .newborn: ".",
            .familiar: ".",
            .settled: "..",
            .bonded: "...",
            .devoted: "....",
            .eternal: ".....",
        ],
    ]

    /// Return the character-voiced stage label. Falls back to the engineering
    /// stage name (`.label`) if the character/stage pair isn't mapped —
    /// which also means a custom future character never leaks "Bonded" as
    /// long as it registers its own stage words.
    public static func stageLabel(character: String, stage: EvolutionStage) -> String {
        if let label = stageLabels[character]?[stage] { return label }
        return stage.label
    }
}
