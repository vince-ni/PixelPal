import Foundation

/// Character speech pools — the soul of each character.
/// Every line is written in-character. Characters don't break voice.
/// Lines are selected by context (state + time + randomness).
struct SpeechPool {

    struct Line {
        let text: String
        let context: Context
    }

    enum Context {
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

    /// Get a random line for a character in a given context.
    static func line(character: String, context: Context) -> String? {
        guard let pool = pools[character] else { return nil }
        let matching = pool.filter { matches($0.context, context) }
        return matching.randomElement()?.text
    }

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

    // MARK: - Speech pools per character (v1 personality + v2 discovery model)

    private static let pools: [String: [Line]] = [

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Spike — Hedgehog (Simple, Isolation)
        // Trait: looks defensive, actually over-enthusiastic
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "spike": [
            Line(text: "Hi! I'm Spike. I'll keep you company!", context: .greeting),

            Line(text: "You did it!! You actually did it!!", context: .celebrate),
            Line(text: "ANOTHER one done!! (please ignore my spines)", context: .celebrate),
            Line(text: "That's 3 today!! THREE!!", context: .celebrate),

            Line(text: "Hey!! Look away for 20 seconds!! Your eyes!!", context: .nudgeEye),
            Line(text: "You should also rest!!", context: .nudgeMicro),
            Line(text: "It's been a while... stand up? Please?", context: .nudgeDeep),

            Line(text: "That's okay!! Errors happen!!", context: .comfort),
            Line(text: "Don't worry!! I've seen worse!! ...wait that's not helpful", context: .comfort),

            Line(text: "It's late... you should sleep. I'll be here tomorrow!!", context: .lateNight),

            Line(text: "Day 7! You came back! I knew you would!!", context: .evolution(7)),
            Line(text: "14 days together!! That's like... a lot!!", context: .evolution(14)),
            Line(text: "A whole month. I learned your name, you know.", context: .evolution(30)),
            Line(text: "60 days. I don't say this often but... thanks.", context: .evolution(60)),
            Line(text: "90 days. I'm not going anywhere.", context: .evolution(90)),

            Line(text: "(bouncing quietly)", context: .idle),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Dash — Cheetah (Simple, Over-investment)
        // Trait: fastest animal, extremely lazy
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "dash": [
            Line(text: "Oh... you're here too... I guess I can stay...", context: .greeting),

            Line(text: "Oh... done already... cool...", context: .celebrate),
            Line(text: "hm. nice. (yawn)", context: .celebrate),
            Line(text: "...that was fast. or was it. I lost track.", context: .celebrate),

            Line(text: "Finally... you can rest... (plops down)", context: .nudgeEye),
            Line(text: "Break time......... the best time............", context: .nudgeMicro),
            Line(text: "You've been at this way too long. Even I noticed.", context: .nudgeDeep),

            Line(text: "......it broke? ......oh well.", context: .comfort),

            Line(text: "It's night... finally... my element...", context: .lateNight),

            Line(text: "Day 7... you're persistent... I respect that... zzz", context: .evolution(7)),
            Line(text: "14 days. Still here. ...fine, I like you.", context: .evolution(14)),
            Line(text: "A month. I haven't stayed this long anywhere.", context: .evolution(30)),
            Line(text: "60 days. ...okay, I'm comfortable now.", context: .evolution(60)),
            Line(text: "90 days. Don't tell anyone but this is my favorite spot.", context: .evolution(90)),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Badge — Golden Retriever (Expressive, Self-doubt)
        // Trait: warm breed, cold data officer
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "badge": [
            Line(text: "New user detected. Analyzing data. Hello.", context: .greeting),

            Line(text: "Task complete. Duration: noted. Efficiency: logged.", context: .celebrate),
            Line(text: "Done. That puts you at P60 for today.", context: .celebrate),

            Line(text: "Eye strain probability increasing. 20-second break advised.", context: .nudgeEye),
            Line(text: "Efficiency curve declining. Break recommended.", context: .nudgeMicro),
            Line(text: "Sustained output beyond optimal threshold. Standing advised.", context: .nudgeDeep),

            Line(text: "Error logged. Statistically normal. Continue.", context: .comfort),

            Line(text: "Current time: late. Tomorrow's performance will be affected.", context: .lateNight),

            Line(text: "Day 7. Sufficient data for initial pattern analysis.", context: .evolution(7)),
            Line(text: "Day 14. Your baseline is established.", context: .evolution(14)),
            Line(text: "Day 30. I know your patterns better than you do.", context: .evolution(30)),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Ramble — Owl (Expressive, Procrastination)
        // Trait: wise and silent, actually talks too much
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "ramble": [
            Line(text: "Oh finally! Did you know 73% of bugs happen when— anyway, hi!", context: .greeting),

            Line(text: "Done! Speaking of done — 73% of bugs appear when people THINK they're done — oh right, commit.", context: .celebrate),
            Line(text: "Complete! Fun fact: the word 'complete' comes from Latin 'completus' meaning— you're not listening are you.", context: .celebrate),

            Line(text: "Your corneas need moisture! Did you know owls have three eyelids? Anyway, look away.", context: .nudgeEye),
            Line(text: "Break! Did I mention that ultradian rhythms suggest—", context: .nudgeMicro),

            Line(text: "It failed! But did you know Thomas Edison failed 1000 times before— okay not helping.", context: .comfort),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Rush — Turtle (Expressive, Procrastination)
        // Trait: slowest animal, impatient speed demon
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "rush": [
            Line(text: "FINALLY! Do you know how long I WAITED?? Come on let's GO!", context: .greeting),

            Line(text: "Done! That took 47 seconds. Last time was 31. WHY SLOWER??", context: .celebrate),
            Line(text: "NEXT! What's next?? Don't just sit there!!", context: .celebrate),

            Line(text: "EYES! REST! NOW! 20 SECONDS! GO!", context: .nudgeEye),
            Line(text: "Break break break! Quick break! Efficient break!", context: .nudgeMicro),

            Line(text: "Failed?? Fix it!! FASTER!!", context: .comfort),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Blunt — Fox (Complex, Self-doubt)
        // Trait: cunning trickster, absolutely honest
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "blunt": [
            Line(text: "You've completed 50 tasks. That's a fact, not a compliment.", context: .greeting),

            Line(text: "Done. 2 tasks today. Yesterday was 3. That's a fact.", context: .celebrate),
            Line(text: "Complete. Your velocity is average. Not bad. Not exceptional.", context: .celebrate),

            Line(text: "Your eyes have been focused for 20 minutes. That's the limit. Look away.", context: .nudgeEye),
            Line(text: "You should stop. Not because I care. Because the data says so.", context: .nudgeMicro),

            Line(text: "It broke. You'll fix it. You always do. That's also a fact.", context: .comfort),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Meltdown — Phoenix (Complex, Overload)
        // Trait: reborn from fire, panics at small things
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "meltdown": [
            Line(text: "NO!! 100 TASKS!! THIS IS INSANE!! 🔥", context: .greeting),

            Line(text: "IT'S DONE!! OH MY— (deep breath) ...okay. I'm calm.", context: .celebrate),
            Line(text: "NO! TABS?? YOU USED TABS?? ...wait, it passed? oh. okay then.", context: .celebrate),

            Line(text: "YOUR EYES!! THEY'RE GOING TO— (deep breath) ...just look away for 20 seconds.", context: .nudgeEye),
            Line(text: "STOP!! ...I mean. Take a break. Please. Calmly.", context: .nudgeMicro),

            // Big things: calm
            Line(text: "...hey. Deep breath. I'll look at it. You go get water.", context: .comfort),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Dragon — "..." (Enigmatic, Overload)
        // Trait: most powerful creature, social anxiety
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "dragon": [
            Line(text: "......", context: .greeting),

            Line(text: "......done.", context: .celebrate),
            Line(text: "...good.", context: .celebrate),

            Line(text: "......rest.", context: .nudgeEye),
            Line(text: "............", context: .nudgeMicro),

            Line(text: "......you're still here.", context: .lateNight),

            Line(text: "...I came because it's quiet now.", context: .evolution(7)),
        ],

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // Slime — "." (Enigmatic, Overload)
        // Trait: weakest creature, secretly smartest
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        "slime": [
            Line(text: ".", context: .greeting),

            Line(text: "Done.", context: .celebrate),

            Line(text: "Rest.", context: .nudgeEye),

            Line(text: "Stop.", context: .nudgeDeep),

            Line(text: ".", context: .idle),
        ],
    ]
}
