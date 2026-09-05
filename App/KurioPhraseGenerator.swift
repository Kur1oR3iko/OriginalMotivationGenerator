import Foundation

enum KurioPhraseGenerator {
    struct Phrase: Equatable {
        let verb: String
        let adjective: String
        let noun: String

        var text: String { verb + adjective + "的" + noun }
    }

    private static let poolSize = 225
    static let totalCombinations = poolSize * poolSize * poolSize
    private static let multiplier = 104_729 // Coprime with 225³, so this visits every combination exactly once.
    private static let cursorKey = "originalMotivationGenerator.v1.cursor"
    private static let offsetKey = "originalMotivationGenerator.v1.offset"

    private static let lastPhraseKey = "originalMotivationGenerator.v1.lastPhrase"

    static var generatedCount: Int {
        UserDefaults.standard.integer(forKey: cursorKey)
    }

    static var lastPhrase: Phrase? {
        // Keep restoring the string saved by earlier versions without advancing the cursor.
        guard let text = UserDefaults.standard.string(forKey: lastPhraseKey),
              let verb = verbs.first(where: { text.hasPrefix($0) }) else { return nil }
        let remainder = text.dropFirst(verb.count).split(separator: "的", maxSplits: 1)
        guard remainder.count == 2,
              adjectives.contains(String(remainder[0])),
              nouns.contains(String(remainder[1])) else { return nil }
        return Phrase(verb: verb, adjective: String(remainder[0]), noun: String(remainder[1]))
    }

    static func reset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: cursorKey)
        defaults.removeObject(forKey: offsetKey)
        defaults.removeObject(forKey: lastPhraseKey)
    }

    static func next() -> Phrase? {
        assert(verbs.count == poolSize)
        assert(adjectives.count == poolSize)
        assert(nouns.count == poolSize)

        let defaults = UserDefaults.standard
        let cursor = defaults.integer(forKey: cursorKey)
        guard cursor < totalCombinations else { return nil }

        let offset: Int
        if defaults.object(forKey: offsetKey) == nil {
            offset = Int.random(in: 0..<totalCombinations)
            defaults.set(offset, forKey: offsetKey)
        } else {
            offset = defaults.integer(forKey: offsetKey)
        }

        let combination = (cursor * multiplier + offset) % totalCombinations
        let verbIndex = combination % poolSize
        let adjectiveIndex = (combination / poolSize) % poolSize
        let nounIndex = (combination / poolSize / poolSize) % poolSize
        defaults.set(cursor + 1, forKey: cursorKey)

        let phrase = Phrase(verb: verbs[verbIndex], adjective: adjectives[adjectiveIndex], noun: nouns[nounIndex])
        defaults.set(phrase.text, forKey: lastPhraseKey)
        return phrase
    }

    private static func words(_ source: String) -> [String] {
        source
            .components(separatedBy: "、")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static let verbs = words("""
    折叠、假设、凝视、测序、协商、渲染、推导、质询、繁殖、追问、拼贴、进化、重构、倾听、代谢、解码、涂抹、感知、悬置、打捞、诊断、改革、反思、治愈、剪辑、
    点燃、遗传、校准、漂浮、突变、监督、描摹、适应、放逐、保存、铭记、拆解、论证、遗忘、擦除、投票、做梦、编织、召回、压抑、怀疑、迁移、认同、搅拌、驯服、
    授权、裁决、朗诵、压缩、起诉、等待、证伪、辩诉、分配、唤醒、立法、装裱、标记、执法、谈判、过滤、仲裁、埋葬、模拟、审判、策展、妥协、举证、丈量、改编、
    签约、刷新、穿越、融资、命名、动员、投资、雕刻、归档、借贷、抚平、回应、储蓄、拓印、冻结、结算、观察、复制、估值、组合、问责、交易、推演、收割、焊接、
    放大、治理、锻造、拆封、烧灼、切削、投射、擦亮、组装、重演、组织、耕作、孵化、旋转、灌溉、修订、记录、放牧、挑战、临摹、酿造、敲击、颠覆、祭祀、维护、
    漂洗、祈祷、删除、收藏、朝圣、照亮、聚合、占卜、排练、展开、考证、缝合、解构、发掘、保护、加速、编年、分散、重启、征服、拒绝、播种、防御、划分、邀请、
    撤退、承认、发表、包围、改写、连接、侦察、隐藏、显现、曝光、触碰、抽取、对焦、塑造、演绎、显影、质疑、辩护、录音、制定、执行、演奏、审议、表决、歌唱、
    罢免、联合、共鸣、抵抗、争取、安慰、揭示、定义、怀念、否定、肯定、衰老、扬弃、超越、生长、生成、暂停、消逝、读取、锁定、回忆、解锁、编译、变形、翻译、
    梦游、映照、吹散、幻化、熔化、铸造、异化、抛光、染色、社会化、预测、回溯、整合、携带、丢弃、制造、安放、移动、探索、漫游、告别、绕行、计算、求解、验证
    """)

    private static let adjectives = words("""
    荒诞、科学、温柔、透明、实验性、锋利、朦胧、理论性、宏大、琐碎、可观测、孤独、公开、可计算、隐秘、古老、可测量、崭新、轻盈、守恒、沉重、潮湿、量子化、干燥、滚烫、
    冰冷、相对论式、柔软、坚硬、统计性、明亮、昏暗、有理、喧闹、安静、无理、缓慢、迅疾、对称、精确、模糊、非对称、复杂、简单、线性、浪漫、理性、非线性、感性、机械化、
    可微、手工化、数字化、收敛、模拟化、像素化、发散、流动、静止、完备、悬浮、下沉、活体、膨胀、收缩、生物性、重复、唯一、遗传性、多余、必要、适应性、过时、未来感、共生、
    现实感、梦幻、寄生、斑驳、纯粹、免疫性、精致、粗糙、神经性、克制、张扬、细胞性、谨慎、大胆、有生命、迟到、提前、焦虑、无声、有形、冲动、无形、有限、冷漠、无限、
    连续、内向、离散、稳定、外向、摇摆、封闭、依恋、开放、随机、偏执、确定、可逆、司法性、不可逆、有机、法定、合成、天然、合宪、人造、平凡、违宪、奇异、天真、
    有效、成熟、顽固、无效、敏感、迟钝、有罪、幽默、严肃、无罪、含蓄、坦率、强制性、发光、褪色、自愿、柔和、刺眼、盈利、低频、高频、亏损、无边、微小、高杠杆、
    庞大、空白、低风险、拥挤、稀薄、通胀性、浓郁、甜蜜、紧缩性、苦涩、清醒、投机性、困倦、诚实、审慎、虚构、偶然、信用化、必然、短暂、金融化、永恒、公共、工业化、私人、
    集体、标准化、自治、集中、模块化、合法、非法、自动化、正当、失当、耐磨、公平、偏颇、易燃、中立、激进、精密、保守、进步、批量化、多元、单一、重型、普遍、特殊、
    乡土、主观、客观、神圣、先验、经验性、世俗、辩证、形而上、历史性、存在主义式、虚无主义式、军事化、自我指涉、不可知、纪实、包容、排他、和谐、自洽、矛盾、超现实、自由、平等、社会性
    """)

    private static let nouns = words("""
    黄昏、科学、算法、社会契约、物理学、早餐、回声、化学、权力、画布、生物学、缓存、自由意志、天文学、公交卡、月光、地质学、制度、像素、生态系统、花园、蒙太奇、原子、主体、选票、
    分子、雨伞、黑洞、细胞、身份、旋律、数学、预算、镜子、几何、记忆、终端、代数、阶级、舞台、微积分、钥匙串、秩序、拓扑、幽灵、政策、概率、沙发、虚无、集合、
    光标、公民、矩阵、雕塑、因果律、函数、饭团、边界、定理、噪声、民主、生命、档案、岛屿、基因、叙述者、意识形态、染色体、芯片、窗台、神经元、少数派、节拍、器官、本体、
    免疫、程序、联盟、物种、胶片、日历、进化、治理、梦境、代谢、脚步、接口、胚胎、传统、观众、心理、语言、城市、潜意识、齿轮、提案、人格、笔记、社会、认知、
    空间、演员、焦虑、引擎、程序正义、依恋、走廊、变量、创伤、共同体、剧场、动机、时间、地图、自我、媒体、心跳、本我、艺术史、市场、法律、键盘、现象、宪法、议会、
    法庭、墨水、身份政治、证据、星球、钟表、判例、客体、资源、契约、光线、民意、法官、书页、宇宙、陪审团、货币、频率、诉讼、历史、菜单、司法、哲学、社区、金融、
    海岸、电路、资本、多数派、标点、股票、革命、房间、债券、话语、磁盘、利率、国家、陌生人、通货膨胀、协议、制度惯性、银行、呼吸、文件、债务、国际秩序、纸箱、利润、公共领域、
    风险、影子、博物馆、工厂、真理、机器人、机床、声音、权利、流水线、屏幕、荒原、乡土、公民社会、意识、村庄、剧本、网络、神话、代际公平、窗户、宗教、指令、政策窗口、神祇、
    作者、欲望、历史学、社会性别、坐标、考古学、展厅、历史叙事、军队、按钮、认识论、战争、群众、乌托邦、摄影、新闻、方法论、音乐、地铁、存在、超现实主义、议程、情绪、色块、世界观
    """)
}
