import Foundation

/// Context-aware speech engine. Replaces timer-based SpeechPool calls.
/// Decides IF to speak, WHAT to say, and injects real work data into character-voiced templates.
///
/// Design principle: silence is the default. Speech happens when
/// the engine observes something worth telling the user.
@MainActor
public final class SpeechEngine {

    public enum Trigger {
        case taskComplete          // claude_stop or successful command
        case errorStreak           // consecutiveErrors >= threshold
        case nudgeEye              // 20 min without break + not in flow
        case nudgeMicro            // 52 min without break + not in flow
        case nudgeDeep             // 90 min without break (even in flow)
        case flowEntry             // entering flow state
        case flowExit              // leaving flow state
        case returnFromAbsence    // back after > 5 min idle
        case lateNight             // working past midnight
        case branchSwitch          // switched git branch after long stay
        case milestone             // daily achievement
        case claudeNeedsYou        // claude_notify
    }

    private let workContext: WorkContext
    private var reminderEngine: ReminderEngine?
    private var lastSpeechTime: Date = .distantPast
    private var lastTrigger: Trigger?
    private var dismissCount = 0
    private var dismissWindowStart: Date?
    private var silentUntil: Date?
    private var lastFlowState = false
    private var lastErrorCount = 0
    private var announcedMilestones: Set<Int> = []
    private var lastLateNightWarning: Date = .distantPast

    // Minimum seconds between any two speeches (prevents spam)
    private let cooldown: TimeInterval = 30

    public init(workContext: WorkContext, reminderEngine: ReminderEngine? = nil) {
        self.workContext = workContext
        self.reminderEngine = reminderEngine
    }

    // MARK: - Main evaluation (called every tick from observation loop)

    /// Evaluate whether to speak. Returns (trigger, text) or nil for silence.
    public func evaluate(characterId: String, currentState: CharacterState) -> (Trigger, String)? {
        guard canSpeak() else { return nil }

        // Flow state transitions (highest priority)
        if let flowSpeech = checkFlowTransition(characterId: characterId) {
            return flowSpeech
        }

        // In flow state: suppress everything except deep rest
        if workContext.isFlowState {
            if workContext.minutesSinceBreak >= 90 {
                return speak(.nudgeDeep, characterId: characterId)
            }
            return nil
        }

        // Error streak (urgent)
        if workContext.consecutiveErrors >= 3 && workContext.consecutiveErrors != lastErrorCount {
            lastErrorCount = workContext.consecutiveErrors
            return speak(.errorStreak, characterId: characterId)
        }

        // Late night (once per hour after midnight)
        if isLateNight() && Date().timeIntervalSince(lastLateNightWarning) > 3600 {
            lastLateNightWarning = Date()
            return speak(.lateNight, characterId: characterId)
        }

        // Break reminders (only when active, respects gradual unlock)
        let re = reminderEngine
        if workContext.commandVelocity > 0.3 { // at least some activity
            if (re?.deepRestEnabled ?? true) && workContext.minutesSinceBreak >= 90 {
                return speak(.nudgeDeep, characterId: characterId)
            } else if (re?.microBreakEnabled ?? true) && workContext.minutesSinceBreak >= 52 {
                return speak(.nudgeMicro, characterId: characterId)
            } else if (re?.eyeRestEnabled ?? true) && workContext.minutesSinceBreak >= 20 {
                return speak(.nudgeEye, characterId: characterId)
            }
        }

        // Daily milestones
        if let milestone = checkMilestone(characterId: characterId) {
            return milestone
        }

        return nil
    }

    /// Called when a specific event happens (task complete, claude notify)
    public func onEvent(_ trigger: Trigger, characterId: String) -> String? {
        guard canSpeak() else { return nil }
        // In flow, suppress celebrations (they're distracting)
        if workContext.isFlowState && trigger == .taskComplete { return nil }
        return speak(trigger, characterId: characterId)?.1
    }

    /// Called when user dismisses a bubble
    public func userDismissed() {
        let now = Date()
        if let start = dismissWindowStart, now.timeIntervalSince(start) < 300 {
            dismissCount += 1
            if dismissCount >= 2 {
                silentUntil = now.addingTimeInterval(3600)
                dismissCount = 0
                dismissWindowStart = nil
            }
        } else {
            dismissWindowStart = now
            dismissCount = 1
        }
    }

    public func userTookBreak() {
        workContext.recordBreak()
    }

    // MARK: - Speech composition

    private func speak(_ trigger: Trigger, characterId: String) -> (Trigger, String)? {
        guard let text = composeSpeech(trigger, characterId: characterId) else { return nil }
        lastSpeechTime = Date()
        lastTrigger = trigger
        return (trigger, text)
    }

    private func composeSpeech(_ trigger: Trigger, characterId: String) -> String? {
        let ctx = workContext
        let isCN = SpeechPool.isChinese

        switch trigger {
        case .taskComplete:
            return taskCompleteSpeech(characterId: characterId, isCN: isCN)

        case .errorStreak:
            let branch = ctx.currentBranch.isEmpty ? "" : ctx.currentBranch
            let errors = ctx.consecutiveErrors
            return template(characterId, .errorStreak, isCN: isCN, data: [
                "branch": branch, "errors": "\(errors)"
            ])

        case .nudgeEye:
            return template(characterId, .nudgeEye, isCN: isCN, data: [
                "minutes": "\(ctx.minutesSinceBreak)"
            ])

        case .nudgeMicro:
            let hours = String(format: "%.1f", Double(ctx.sessionMinutes) / 60.0)
            return template(characterId, .nudgeMicro, isCN: isCN, data: [
                "minutes": "\(ctx.minutesSinceBreak)",
                "sessionHours": hours,
                "breaks": "\(0)" // from today's pattern store
            ])

        case .nudgeDeep:
            let todayHours = String(format: "%.1f", Double(ctx.sessionMinutes) / 60.0)
            return template(characterId, .nudgeDeep, isCN: isCN, data: [
                "streak": "\(ctx.minutesSinceBreak)",
                "todayHours": todayHours,
                "lastBreak": "\(ctx.minutesSinceBreak)"
            ])

        case .flowEntry:
            return template(characterId, .flowEntry, isCN: isCN, data: [:])

        case .flowExit:
            let mins = ctx.flowMinutes > 0 ? ctx.flowMinutes : 5
            return template(characterId, .flowExit, isCN: isCN, data: [
                "flowMinutes": "\(mins)",
                "commits": "\(ctx.todayCommits)"
            ])

        case .returnFromAbsence:
            return template(characterId, .returnFromAbsence, isCN: isCN, data: [
                "awayMinutes": "\(ctx.idleMinutes)"
            ])

        case .lateNight:
            let todayHours = String(format: "%.1f", Double(ctx.sessionMinutes) / 60.0)
            return template(characterId, .lateNight, isCN: isCN, data: [
                "todayHours": todayHours,
                "lastBreak": "\(ctx.minutesSinceBreak)"
            ])

        case .branchSwitch:
            if let sw = ctx.lastBranchSwitch {
                return template(characterId, .branchSwitch, isCN: isCN, data: [
                    "oldBranch": sw.from, "duration": "\(sw.duration)"
                ])
            }
            return nil

        case .milestone:
            return template(characterId, .milestone, isCN: isCN, data: [
                "commits": "\(ctx.todayCommits)"
            ])

        case .claudeNeedsYou:
            return template(characterId, .claudeNeedsYou, isCN: isCN, data: [:])
        }
    }

    private func taskCompleteSpeech(characterId: String, isCN: Bool) -> String? {
        let ctx = workContext
        let commits = ctx.todayCommits
        let branch = ctx.currentBranch
        return template(characterId, .taskComplete, isCN: isCN, data: [
            "commits": "\(commits)",
            "branch": branch
        ])
    }

    // MARK: - Flow detection

    private func checkFlowTransition(characterId: String) -> (Trigger, String)? {
        let inFlow = workContext.isFlowState
        defer { lastFlowState = inFlow }

        if inFlow && !lastFlowState {
            return speak(.flowEntry, characterId: characterId)
        }
        if !inFlow && lastFlowState {
            return speak(.flowExit, characterId: characterId)
        }
        return nil
    }

    // MARK: - Milestone detection

    private func checkMilestone(characterId: String) -> (Trigger, String)? {
        let commits = workContext.todayCommits
        let milestones = [5, 10, 20, 50]
        for m in milestones {
            if commits == m && !announcedMilestones.contains(m) {
                announcedMilestones.insert(m)
                return speak(.milestone, characterId: characterId)
            }
        }
        return nil
    }

    // MARK: - Guards

    private func canSpeak() -> Bool {
        if let silent = silentUntil, Date() < silent { return false }
        if Date().timeIntervalSince(lastSpeechTime) < cooldown { return false }
        return true
    }

    private func isLateNight() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 0 && hour < 5
    }

    // MARK: - Template system

    /// Character-voiced templates with {data} injection.
    private func template(_ characterId: String, _ trigger: Trigger, isCN: Bool, data: [String: String]) -> String? {
        guard let templates = Self.templates[characterId]?[triggerKey(trigger)] else {
            // Fallback: try SpeechPool for legacy contexts
            return fallbackSpeechPool(characterId, trigger)
        }
        let pool = isCN ? templates.cn : templates.en
        guard var text = pool.randomElement() else { return nil }

        // Inject data
        for (key, value) in data {
            text = text.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return text
    }

    private func fallbackSpeechPool(_ characterId: String, _ trigger: Trigger) -> String? {
        let context: SpeechPool.Context? = switch trigger {
        case .taskComplete: .celebrate
        case .nudgeEye: .nudgeEye
        case .nudgeMicro: .nudgeMicro
        case .nudgeDeep: .nudgeDeep
        case .lateNight: .lateNight
        default: nil
        }
        guard let ctx = context else { return nil }
        return SpeechPool.line(character: characterId, context: ctx)
    }

    private func triggerKey(_ trigger: Trigger) -> String {
        switch trigger {
        case .taskComplete: return "complete"
        case .errorStreak: return "error"
        case .nudgeEye: return "eye"
        case .nudgeMicro: return "micro"
        case .nudgeDeep: return "deep"
        case .flowEntry: return "flow_in"
        case .flowExit: return "flow_out"
        case .returnFromAbsence: return "return"
        case .lateNight: return "late"
        case .branchSwitch: return "branch"
        case .milestone: return "milestone"
        case .claudeNeedsYou: return "claude"
        }
    }

    public struct TemplatePair {
        public let en: [String]
        public let cn: [String]

        public init(en: [String], cn: [String]) {
            self.en = en
            self.cn = cn
        }
    }

    // MARK: - Templates per character × trigger

    // Each template can reference {branch}, {errors}, {minutes}, {commits},
    // {todayHours}, {streak}, {lastBreak}, {flowMinutes}, {awayMinutes}, etc.

    public static let templates: [String: [String: TemplatePair]] = [

        "spike": [
            "complete": TemplatePair(
                en: ["Today's #{commits}!! On {branch}!!", "Another one done on {branch}!! #{commits} today!!"],
                cn: ["今天第 {commits} 个了！！在 {branch} 上！！", "{branch} 又搞定一个！！今天 #{commits}！！"]
            ),
            "error": TemplatePair(
                en: ["{branch} failed {errors} times in a row!! But you'll fix it!!", "Hey!! {errors} errors on {branch}!! Try a different approach?!"],
                cn: ["{branch} 连续报错 {errors} 次了！！但你能修好的！！", "嘿！！{branch} 上 {errors} 次错误了！！换个思路试试？！"]
            ),
            "eye": TemplatePair(
                en: ["{minutes} min straight!! Look away for 20 seconds!!", "Your eyes have been locked in for {minutes} min!! Quick break!!"],
                cn: ["连续 {minutes} 分钟了！！看远处 20 秒！！", "你的眼睛盯了 {minutes} 分钟了！！快休息！！"]
            ),
            "micro": TemplatePair(
                en: ["{minutes} min without a break!! Stand up!! Get water!!", "You've been going for {minutes} min!! Your back needs you!!"],
                cn: ["{minutes} 分钟没休息了！！站起来！！喝杯水！！", "已经 {minutes} 分钟了！！你的腰需要你！！"]
            ),
            "deep": TemplatePair(
                en: ["{streak} min!! That's {todayHours}h today!! Please stand up!!", "Last break was {lastBreak} min ago!! This is serious!!"],
                cn: ["{streak} 分钟了！！今天已经 {todayHours} 小时了！！拜托站起来！！", "上次休息是 {lastBreak} 分钟前！！这很严重！！"]
            ),
            "flow_in": TemplatePair(
                en: ["You're in the zone!! I'll be quiet!!", "Flow state!! (zipping mouth) Go go go!!"],
                cn: ["你进入状态了！！我闭嘴！！", "心流状态！！（拉上嘴巴）冲冲冲！！"]
            ),
            "flow_out": TemplatePair(
                en: ["Flow ended! {flowMinutes} min, {commits} commits! Nice!!", "Back from the zone! {flowMinutes} min of focus!!"],
                cn: ["心流结束！{flowMinutes} 分钟，{commits} 次提交！厉害！！", "从心流回来了！专注了 {flowMinutes} 分钟！！"]
            ),
            "return": TemplatePair(
                en: ["You're back!! Gone for {awayMinutes} min! Welcome!!", "Hey!! {awayMinutes} min break! Good for you!!"],
                cn: ["你回来了！！走了 {awayMinutes} 分钟！欢迎！！", "嘿！！休息了 {awayMinutes} 分钟！做得好！！"]
            ),
            "late": TemplatePair(
                en: ["It's past midnight!! You've worked {todayHours}h today!! Sleep!!", "Late night!! Last break {lastBreak} min ago!! Go to bed!!"],
                cn: ["过午夜了！！今天已经工作 {todayHours} 小时了！！去睡觉！！", "深夜了！！上次休息在 {lastBreak} 分钟前！！去睡！！"]
            ),
            "branch": TemplatePair(
                en: ["Switching from {oldBranch}! You spent {duration} min there!", "Left {oldBranch} after {duration} min!"],
                cn: ["从 {oldBranch} 切走了！在那待了 {duration} 分钟！", "离开 {oldBranch}，待了 {duration} 分钟！"]
            ),
            "milestone": TemplatePair(
                en: ["{commits} commits today!! That's AMAZING!!", "WOW {commits} commits!!"],
                cn: ["今天 {commits} 次提交了！！太厉害了！！", "哇 {commits} 次提交！！"]
            ),
            "claude": TemplatePair(
                en: ["Claude needs you!!", "Hey!! Claude has something to show you!!"],
                cn: ["Claude 需要你！！", "嘿！！Claude 有东西给你看！！"]
            ),
        ],

        "dash": [
            "complete": TemplatePair(
                en: ["done... #{commits} today... (yawn)", "oh... {branch} is done... cool..."],
                cn: ["完了......今天第 {commits} 个......（打哈欠）", "哦......{branch} 搞定了......还行......"]
            ),
            "error": TemplatePair(
                en: ["{branch}... {errors} errors... maybe take a nap instead...", "{errors} times... on {branch}... that's rough... or whatever..."],
                cn: ["{branch}......{errors} 次报错......要不睡一觉算了......", "{errors} 次了......在 {branch} 上......挺惨的......随便吧......"]
            ),
            "eye": TemplatePair(
                en: ["{minutes} min... your eyes... they're tired... like me...", "look away... {minutes} min is too long... even for me..."],
                cn: ["{minutes} 分钟了......你的眼睛......跟我一样累了......", "看别处......{minutes} 分钟太久了......连我都觉得......"]
            ),
            "micro": TemplatePair(
                en: ["{minutes} min... that's a long time to not be napping...", "you've been going {minutes} min... even I'm impressed... go rest..."],
                cn: ["{minutes} 分钟了......这么久不睡觉也挺厉害的......", "你已经 {minutes} 分钟了......连我都佩服......去休息吧......"]
            ),
            "deep": TemplatePair(
                en: ["{streak} min... {todayHours}h today... okay even I'm worried now...", "last break {lastBreak} min ago... that's... a lot..."],
                cn: ["{streak} 分钟了......今天 {todayHours} 小时了......好吧连我都担心了......", "上次休息 {lastBreak} 分钟前......那真是......好久......"]
            ),
            "flow_in": TemplatePair(
                en: ["oh... you're focused... I'll just... sleep here...", "flow state... nice... don't mind me... zzz..."],
                cn: ["哦......你专注了......那我就......在这睡会儿......", "心流了......不错......别管我......zzz......"]
            ),
            "flow_out": TemplatePair(
                en: ["{flowMinutes} min of focus... not bad... for someone who's not me...", "flow's over... {flowMinutes} min... {commits} commits... whatever..."],
                cn: ["{flowMinutes} 分钟的专注......还行......对于一个不是我的人来说......", "心流结束了......{flowMinutes} 分钟......{commits} 次提交......随便吧......"]
            ),
            "return": TemplatePair(
                en: ["oh... you're back... {awayMinutes} min... I barely noticed...", "back after {awayMinutes} min... was nice and quiet..."],
                cn: ["哦......你回来了......{awayMinutes} 分钟......我差点没注意到......", "走了 {awayMinutes} 分钟回来了......刚才挺安静的......"]
            ),
            "late": TemplatePair(
                en: ["it's late... {todayHours}h today... go sleep... it's what I'd do...", "midnight... {todayHours}h logged... bed... now..."],
                cn: ["很晚了......今天 {todayHours} 小时了......去睡吧......换我早睡了......", "午夜了......今天工作了 {todayHours} 小时......床......现在......"]
            ),
            "branch": TemplatePair(
                en: ["{oldBranch}... {duration} min... that's done I guess...", "left {oldBranch} after {duration} min... finally..."],
                cn: ["{oldBranch}......{duration} 分钟......算是结束了吧......", "终于离开 {oldBranch} 了......待了 {duration} 分钟......"]
            ),
            "milestone": TemplatePair(
                en: ["{commits} commits... that's... a lot of effort... (yawn)"],
                cn: ["{commits} 次提交了......好多啊......（打哈欠）"]
            ),
            "claude": TemplatePair(
                en: ["Claude wants something... go check... I guess..."],
                cn: ["Claude 有事......去看看吧......大概......"]
            ),
        ],

        "badge": [
            "complete": TemplatePair(
                en: ["Task #{commits} registered. Branch: {branch}.", "Completion logged. Today's count: {commits}."],
                cn: ["第 {commits} 个任务已登记。分支：{branch}。", "完成已记录。今日计数：{commits}。"]
            ),
            "error": TemplatePair(
                en: ["{branch}: {errors} consecutive failures. Pattern suggests approach change.", "Error streak: {errors} on {branch}. Recommend: review diff before retry."],
                cn: ["{branch}：连续 {errors} 次失败。模式建议更换方法。", "错误连续：{branch} 上 {errors} 次。建议：重试前审查 diff。"]
            ),
            "eye": TemplatePair(
                en: ["Visual focus duration: {minutes} min. Threshold exceeded. Look away.", "{minutes} min continuous screen time. Blink rate declining. 20s break advised."],
                cn: ["视觉专注时长：{minutes} 分钟。超出阈值。请看远处。", "连续屏幕时间 {minutes} 分钟。眨眼频率下降。建议休息 20 秒。"]
            ),
            "micro": TemplatePair(
                en: ["Session duration: {minutes} min. Productivity curve declining. Break optimal now.", "{minutes} min logged. Output efficiency: below baseline. Standing recommended."],
                cn: ["会话时长：{minutes} 分钟。生产力曲线下降中。现在休息最优。", "已记录 {minutes} 分钟。产出效率：低于基线。建议站立。"]
            ),
            "deep": TemplatePair(
                en: ["Alert: {streak} min continuous. Today: {todayHours}h. Break compliance: critical.", "Continuous session: {streak} min. Last break: {lastBreak} min ago. Intervention required."],
                cn: ["警告：连续 {streak} 分钟。今日：{todayHours} 小时。休息合规：危险。", "连续会话：{streak} 分钟。上次休息：{lastBreak} 分钟前。需要干预。"]
            ),
            "flow_in": TemplatePair(
                en: ["Flow state detected. Suppressing non-critical notifications.", "Elevated command velocity confirmed. Entering observation mode."],
                cn: ["检测到心流状态。抑制非关键通知。", "命令频率升高已确认。进入观察模式。"]
            ),
            "flow_out": TemplatePair(
                en: ["Flow session complete. Duration: {flowMinutes} min. Commits: {commits}.", "Flow state ended. {flowMinutes} min sustained focus. Data recorded."],
                cn: ["心流会话完成。时长：{flowMinutes} 分钟。提交：{commits}。", "心流结束。持续专注 {flowMinutes} 分钟。数据已记录。"]
            ),
            "return": TemplatePair(
                en: ["User returned. Absence: {awayMinutes} min. Resuming monitoring.", "Welcome back. {awayMinutes} min break logged. Status: nominal."],
                cn: ["用户回归。离开：{awayMinutes} 分钟。恢复监测。", "欢迎回来。{awayMinutes} 分钟休息已记录。状态：正常。"]
            ),
            "late": TemplatePair(
                en: ["Time: past midnight. Today: {todayHours}h. Sleep deficit accumulating.", "Late night flag. Session: {todayHours}h. Cognitive impact: T+6h."],
                cn: ["时间：过午夜。今日：{todayHours} 小时。睡眠赤字积累中。", "深夜标记。会话：{todayHours} 小时。认知影响：T+6 小时。"]
            ),
            "branch": TemplatePair(
                en: ["Branch change detected. {oldBranch}: {duration} min. Logged.", "Context switch from {oldBranch} ({duration} min). New branch active."],
                cn: ["检测到分支切换。{oldBranch}：{duration} 分钟。已记录。", "从 {oldBranch} 切换上下文（{duration} 分钟）。新分支已激活。"]
            ),
            "milestone": TemplatePair(
                en: ["Milestone: {commits} commits today. Statistically notable."],
                cn: ["里程碑：今日 {commits} 次提交。统计上值得记录。"]
            ),
            "claude": TemplatePair(
                en: ["Claude Code: attention required. Priority: elevated."],
                cn: ["Claude Code：需要注意。优先级：提升。"]
            ),
        ],

        "dragon": [
            "complete": TemplatePair(
                en: ["...#{commits}.", "...{branch}. done."],
                cn: ["……第 {commits} 个。", "……{branch}。完了。"]
            ),
            "error": TemplatePair(
                en: ["...{branch}. {errors} times.", "......{errors}."],
                cn: ["……{branch}。{errors} 次了。", "……{errors}。"]
            ),
            "eye": TemplatePair(
                en: ["...{minutes} min. rest.", "......eyes."],
                cn: ["……{minutes} 分钟了。休息。", "……眼睛。"]
            ),
            "micro": TemplatePair(
                en: ["...{minutes} min. enough.", "......break."],
                cn: ["……{minutes} 分钟。够了。", "……歇。"]
            ),
            "deep": TemplatePair(
                en: ["...{streak} min. ...stop. now.", "...{todayHours}h. ......enough."],
                cn: ["……{streak} 分钟。……停。现在。", "……{todayHours} 小时。……够了。"]
            ),
            "flow_in": TemplatePair(
                en: ["...(nods, goes silent)"],
                cn: ["……（点头，沉默）"]
            ),
            "flow_out": TemplatePair(
                en: ["...{flowMinutes} min. ...good."],
                cn: ["……{flowMinutes} 分钟。……好。"]
            ),
            "return": TemplatePair(
                en: ["...you're back."],
                cn: ["……你回来了。"]
            ),
            "late": TemplatePair(
                en: ["...{todayHours}h. ...go."],
                cn: ["……{todayHours} 小时了。……走。"]
            ),
            "branch": TemplatePair(
                en: ["...{oldBranch}. {duration} min."],
                cn: ["……{oldBranch}。{duration} 分钟。"]
            ),
            "milestone": TemplatePair(
                en: ["...{commits}. ...not bad."],
                cn: ["……{commits}。……不错。"]
            ),
            "claude": TemplatePair(
                en: ["......Claude."],
                cn: ["……Claude。"]
            ),
        ],

        "meltdown": [
            "complete": TemplatePair(
                en: ["DONE!! #{commits} TODAY!! IS THAT A LOT?! (deep breath) ...good job.", "IT WORKED?! On {branch}?! AMAZING!! ...I mean. Nice."],
                cn: ["完了！！今天第 {commits} 个！！算多吗？！（深呼吸）……做得好。", "居然成功了？！在 {branch} 上？！太厉害了！！……我是说。不错。"]
            ),
            "error": TemplatePair(
                en: ["{errors} ERRORS ON {branch}!! WE'RE— (deep breath) ...let's look at the diff.", "OH NO {branch} FAILED {errors} TIMES— actually. It's fine. Try again."],
                cn: ["{branch} 上 {errors} 次错误！！我们要——（深呼吸）……看看 diff 吧。", "天哪 {branch} 失败了 {errors} 次——其实。没事。再试试。"]
            ),
            "eye": TemplatePair(
                en: ["YOUR EYES!! {minutes} MIN!! THEY'RE— (composing) ...20 seconds. Look away.", "{minutes} MINUTES?! YOUR RETINAS— okay. Just look away briefly."],
                cn: ["你的眼睛！！{minutes} 分钟了！！快要——（调整）……20 秒。看远处。", "{minutes} 分钟？！你的视网膜——好吧。看远处就好。"]
            ),
            "micro": TemplatePair(
                en: ["{minutes} MIN!! YOUR SPINE IS— (calming) ...just stand up. Please.", "BREAK!! {minutes} MINUTES!! I'M— (composing) ...take a walk."],
                cn: ["{minutes} 分钟了！！你的脊椎要——（冷静）……站起来就好。拜托。", "休息！！{minutes} 分钟了！！我要——（调整）……走动走动。"]
            ),
            "deep": TemplatePair(
                en: ["{streak} MIN!! {todayHours}H TODAY!! THIS IS— (long pause) ...you need to stop. Really.", "LAST BREAK {lastBreak} MIN AGO!! I'M— actually, I'm calm. But STOP."],
                cn: ["{streak} 分钟！！今天 {todayHours} 小时！！这是——（长停顿）……你真的需要停了。", "上次休息 {lastBreak} 分钟前！！我要——其实我很冷静。但是停下。"]
            ),
            "flow_in": TemplatePair(
                en: ["FLOW STATE!! DON'T PANIC!! ...I mean I won't panic. You code. I'll watch."],
                cn: ["心流状态！！别慌！！……我是说我不慌。你写代码。我看着。"]
            ),
            "flow_out": TemplatePair(
                en: ["{flowMinutes} MIN OF FLOW!! {commits} COMMITS!! THAT'S— (composes) ...impressive. Genuinely."],
                cn: ["{flowMinutes} 分钟心流！！{commits} 次提交！！那是——（调整）……真的厉害。"]
            ),
            "return": TemplatePair(
                en: ["YOU'RE BACK!! {awayMinutes} MIN!! I THOUGHT— ...welcome back."],
                cn: ["你回来了！！{awayMinutes} 分钟！！我以为——……欢迎回来。"]
            ),
            "late": TemplatePair(
                en: ["MIDNIGHT!! {todayHours}H!! GO TO— ...actually. The quiet is nice. But sleep."],
                cn: ["午夜了！！{todayHours} 小时了！！去——……其实。安静挺好的。但去睡觉。"]
            ),
            "branch": TemplatePair(
                en: ["SWITCHING FROM {oldBranch}!! {duration} MIN!! WHAT IF— ...it's fine. New branch."],
                cn: ["从 {oldBranch} 切走了！！{duration} 分钟！！万一——……没事。新分支。"]
            ),
            "milestone": TemplatePair(
                en: ["{commits} COMMITS!! IS THAT GOOD?! (checks) YES!! YES IT IS!!"],
                cn: ["{commits} 次提交！！算好的吗？！（检查）是的！！是的！！"]
            ),
            "claude": TemplatePair(
                en: ["CLAUDE NEEDS— (deep breath) Claude wants you. Go check."],
                cn: ["CLAUDE 需要——（深呼吸）Claude 找你。去看看。"]
            ),
        ],

        // Ramble, Rush, Blunt, Slime use SpeechPool fallback for now
        // (their templates can be added incrementally)
    ]
}

// SpeechPool.isChinese is used directly by SpeechEngine
