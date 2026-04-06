import SwiftUI
import AppKit
import Foundation

// MARK: - AI Manager
class AIManager: ObservableObject {
    static let shared = AIManager()
    @Published var isGenerating = false
    @Published var errorMessage: String?
    
    func generateWrongAnswers(question: String, correctAnswer: String, completion: @escaping ([String]?) -> Void) {
        isGenerating = true
        errorMessage = nil
        
        let apiKey = SettingsManager.shared.apiKey
        if apiKey.isEmpty {
            errorMessage = "Введите API ключ в настройках"
            isGenerating = false
            completion(nil)
            return
        }
        
        let prompt = """
        Generate exactly 3 wrong answers for this quiz question. Each wrong answer should be plausible but incorrect. Return ONLY a JSON array of 3 strings, nothing else.
        
        Question: \(question)
        Correct answer: \(correctAnswer)
        
        Return format: ["wrong1", "wrong2", "wrong3"]
        """
        
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("QuizApp", forHTTPHeaderField: "HTTP-Referer")
        
        let body: [String: Any] = [
            "model": "qwen/qwen-2.5-72b-instruct",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isGenerating = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(nil)
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "Нет данных от сервера"
                    completion(nil)
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Check for error response
                        if let errorObj = json["error"] as? [String: Any],
                           let errMsg = errorObj["message"] as? String {
                            self.errorMessage = errMsg
                            completion(nil)
                            return
                        }
                        
                        if let choices = json["choices"] as? [[String: Any]],
                           let first = choices.first,
                           let message = first["message"] as? [String: Any],
                           let content = message["content"] as? String {
                            
                            // Try to find JSON array in response
                            let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Method 1: Direct JSON array
                            if let data = cleaned.data(using: .utf8),
                               let answers = try? JSONSerialization.jsonObject(with: data) as? [String] {
                                if answers.count >= 3 {
                                    completion(Array(answers.prefix(3)))
                                    return
                                }
                            }
                            
                            // Method 2: Find JSON array with regex
                            if let range = cleaned.range(of: "\\[.*\\]", options: .regularExpression) {
                                let jsonArray = String(cleaned[range])
                                if let data = jsonArray.data(using: .utf8),
                                   let answers = try? JSONSerialization.jsonObject(with: data) as? [String] {
                                    if answers.count >= 3 {
                                        completion(Array(answers.prefix(3)))
                                        return
                                    }
                                }
                            }
                            
                            // Method 3: Parse numbered list (1. xxx 2. xxx 3. xxx)
                            let lines = cleaned.components(separatedBy: .newlines)
                            var foundAnswers: [String] = []
                            for line in lines {
                                let trimmed = line.trimmingCharacters(in: .whitespaces)
                                // Match patterns like "1. text" or "- text" or "* text"
                                if let range = trimmed.range(of: "^[\\d\\-\\*]+\\.?\\s*(.+)$", options: .regularExpression) {
                                    let answer = String(trimmed[range]).trimmingCharacters(in: .whitespaces)
                                    if !answer.isEmpty && answer.count > 5 {
                                        foundAnswers.append(answer)
                                    }
                                }
                            }
                            if foundAnswers.count >= 3 {
                                completion(Array(foundAnswers.prefix(3)))
                                return
                            }
                            
                            // Method 4: Split by newlines and take first 3 non-empty lines
                            let nonEmpty = cleaned.components(separatedBy: .newlines)
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty && $0.count > 5 && !$0.hasPrefix("[") && !$0.hasPrefix("{") }
                            if nonEmpty.count >= 3 {
                                completion(Array(nonEmpty.prefix(3)))
                                return
                            }
                            
                            self.errorMessage = "Не удалось распарсить ответ ИИ. Попробуйте ещё раз."
                            completion(nil)
                        } else {
                            self.errorMessage = "Неверный формат ответа от сервера"
                            completion(nil)
                        }
                    } else {
                        self.errorMessage = "Ошибка парсинга JSON"
                        completion(nil)
                    }
                } catch {
                    self.errorMessage = "Ошибка: \(error.localizedDescription)"
                    completion(nil)
                }
            }
        }.resume()
    }
}

// MARK: - Language
enum AppLanguage: String, CaseIterable {
    case russian = "ru"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .russian: return "🇷🇺 Русский"
        case .english: return "🇬🇧 English"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "quizAppLanguage")
        }
    }
    
    init() {
        let saved = UserDefaults.standard.string(forKey: "quizAppLanguage") ?? "ru"
        currentLanguage = AppLanguage(rawValue: saved) ?? .russian
    }
    
    var isRussian: Bool { currentLanguage == .russian }
}

// MARK: - Settings
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    @Published var showTranslations: Bool {
        didSet {
            UserDefaults.standard.set(showTranslations, forKey: "quizAppShowTranslations")
        }
    }
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "quizAppApiKey")
        }
    }
    @Published var showTranslationField: Bool {
        didSet {
            UserDefaults.standard.set(showTranslationField, forKey: "quizAppShowTranslationField")
        }
    }

    init() {
        showTranslations = UserDefaults.standard.object(forKey: "quizAppShowTranslations") as? Bool ?? true
        apiKey = UserDefaults.standard.string(forKey: "quizAppApiKey") ?? ""
        showTranslationField = UserDefaults.standard.object(forKey: "quizAppShowTranslationField") as? Bool ?? true
    }
}


// MARK: - Test (Quiz Set)
struct QuizTest: Identifiable, Codable {
    let id: UUID
    var name: String
    var questionIds: [UUID]
    
    init(id: UUID = UUID(), name: String, questionIds: [UUID]) {
        self.id = id
        self.name = name
        self.questionIds = questionIds
    }
}

class TestManager: ObservableObject {
    static let shared = TestManager()
    
    var fileURL: URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("quiz_tests.json")
    }
    
    func loadTests() -> [QuizTest] {
        guard let data = try? Data(contentsOf: fileURL),
              let tests = try? JSONDecoder().decode([QuizTest].self, from: data) else {
            return []
        }
        return tests
    }
    
    func saveTests(_ tests: [QuizTest]) {
        if let data = try? JSONEncoder().encode(tests) {
            try? data.write(to: fileURL)
        }
    }
    
    func addTest(_ test: QuizTest) {
        var all = loadTests()
        all.append(test)
        saveTests(all)
    }
    
    func deleteTest(id: UUID) {
        var all = loadTests()
        all.removeAll { $0.id == id }
        saveTests(all)
    }
    
    func getQuestions(for test: QuizTest) -> [Question] {
        let allQuestions = QuestionFileManager.shared.loadQuestions()
        return allQuestions.filter { test.questionIds.contains($0.id) }
    }
}

// MARK: - Question
struct Question: Identifiable, Codable {
    let id: UUID
    var question: String
    var correct: String
    var wrong: [String]
    var questionTranslation: String?
    var answerTranslation: String?
    
    init(id: UUID = UUID(), question: String, correct: String, wrong: [String], questionTranslation: String? = nil, answerTranslation: String? = nil) {
        self.id = id
        self.question = question
        self.correct = correct
        self.wrong = wrong
        self.questionTranslation = questionTranslation
        self.answerTranslation = answerTranslation
    }
    
    var allAnswers: [String] {
        var a = wrong
        a.insert(correct, at: Int.random(in: 0...wrong.count))
        return a
    }
}

// MARK: - File Manager
class QuestionFileManager {
    static let shared = QuestionFileManager()
    
    var fileURL: URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("quiz_questions.json")
    }
    
    func loadQuestions() -> [Question] {
        guard let data = try? Data(contentsOf: fileURL),
              let questions = try? JSONDecoder().decode([Question].self, from: data) else {
            return defaultQuestions
        }
        return questions.isEmpty ? defaultQuestions : questions
    }
    
    func saveQuestions(_ questions: [Question]) {
        if let data = try? JSONEncoder().encode(questions) {
            try? data.write(to: fileURL)
        }
    }
    
    func addQuestion(_ q: Question) {
        var all = loadQuestions()
        all.append(q)
        saveQuestions(all)
    }
    
    func deleteQuestion(id: UUID) {
        var all = loadQuestions()
        all.removeAll { $0.id == id }
        saveQuestions(all)
    }
    
    func resetToDefaults() {
        saveQuestions(defaultQuestions)
    }
}

let defaultQuestions: [Question] = [
    Question(question: "What was revolutionary about Gutenberg's concept? How long had the printing press stayed unchanged?", correct: "The revolutionary part was the movable type system using individual metal characters. The mechanics remained unchanged for 300 years.", wrong: ["Gutenberg invented the steam engine which revolutionized printing for 200 years.", "He created the first paper-making machine that lasted 150 years without changes.", "The revolutionary concept was using colored ink, unchanged for 250 years."], questionTranslation: "Что было революционным в концепции Гутенберга? Как долго печатный станок оставался без изменений?", answerTranslation: "Революционным был наборный шрифт из отдельных металлических букв. Конструкция почти не менялась 300 лет."),
    Question(question: "Why did the early printing presses wear down quickly?", correct: "They required great force to operate, which caused the wood to crack and the metal type to wear down over time.", wrong: ["The ink was too acidic and corroded the metal parts within months.", "Workers didn't know how to operate them properly and broke them intentionally.", "The humidity in printing rooms caused rapid rusting of all metal components."], questionTranslation: "Почему ранние печатные станки быстро изнашивались?", answerTranslation: "Они требовали больших усилий, из-за чего дерево трескалось, а металлические буквы изнашивались."),
    Question(question: "Who is recognized as the inventor of the electric light bulb? What key elements led to the triumph of his version?", correct: "Thomas Edison is credited because his version was more practical due to effective materials, a higher vacuum, and high resistance.", wrong: ["Nikola Tesla invented it first using alternating current and special filaments.", "Benjamin Franklin created it with static electricity and glass insulation.", "Alexander Graham Bell invented it while working on telephone technology."], questionTranslation: "Кто считается изобретателем электрической лампочки? Что привело к успеху его версии?", answerTranslation: "Томас Эдисон — его версия была практичнее: эффективные материалы, лучший вакуум и высокое сопротивление."),
    Question(question: "What breakthrough was made by the Wright brothers?", correct: "They invented the first airplane and achieved the first sustained, controlled flight in 1903.", wrong: ["They invented the first hot air balloon and flew over the Atlantic in 1900.", "They created the first helicopter and flew it across France in 1905.", "They built the first jet engine and tested it during World War I."], questionTranslation: "Какой прорыв совершили братья Райт?", answerTranslation: "Они изобрели первый самолёт и совершили первый управляемый полёт в 1903 году."),
    Question(question: "What contraptions preceded the first airplane invented by the Wright brothers?", correct: "Human flight was previously attempted with kites, balloons, and gliders.", wrong: ["People tried flying using mechanical wings attached to bicycles and cars.", "Early attempts included rocket-powered sleds and parachute-equipped horses.", "The main predecessors were steam-powered ornithopters and hot air rockets."], questionTranslation: "Какие устройства предшествовали первому самолёту братьев Райт?", answerTranslation: "До этого люди пытались летать на воздушных змеях, шарах и планёрах."),
    Question(question: "What do you know about the invention made by Joseph Nicéphore Niépce?", correct: "He created a prototype of a photographic camera in 1816 and took the oldest surviving photograph in 1826.", wrong: ["He invented the first color photography process in 1850 using natural dyes.", "He created the first motion picture camera and filmed a short movie in 1830.", "He developed the first digital camera prototype in 1840 using metal plates."], questionTranslation: "Что вы знаете об изобретении Жозефа Нисефора Ньепса?", answerTranslation: "Он создал прототип фотокамеры в 1816 году и сделал старейшую сохранившуюся фотографию в 1826-м."),
    Question(question: "What breakthrough in the automotive industry was made by Carl Benz?", correct: "He patented a gas-powered engine for his car, which led to the creation of the Mercedes-Benz enterprise.", wrong: ["He invented the first electric car battery that could run for 100 miles.", "He created the first rubber tire and sold it to all European car manufacturers.", "He designed the first steering wheel system still used in modern cars today."], questionTranslation: "Какой прорыв в автомобильной промышленности совершил Карл Бенц?", answerTranslation: "Он запатентовал газовый двигатель для автомобиля, что привело к созданию Mercedes-Benz."),
    Question(question: "What was Henry Ford's contribution to the development of the automotive industry?", correct: "He utilized mass-production techniques, specifically the assembly line, making cars affordable for the general public.", wrong: ["He invented the first gasoline engine that was twice as powerful as competitors'.", "He created the first luxury car brand that only rich people could afford.", "He designed the first car with air conditioning and automatic transmission."], questionTranslation: "Какой вклад внёс Генри Форд в развитие автомобильной промышленности?", answerTranslation: "Он внедрил конвейерное производство, сделав автомобили доступными для обычных людей."),
    Question(question: "Who was Alexander Graham Bell? What did he invent?", correct: "He was a scientist and inventor who created the telephone.", wrong: ["He was a musician who invented the first electric guitar and amplifier.", "He was a doctor who invented the first stethoscope for heart monitoring.", "He was a sailor who invented the first submarine communication device."], questionTranslation: "Кем был Александр Грэм Белл? Что он изобрёл?", answerTranslation: "Учёный и изобретатель, создавший телефон."),
    Question(question: "Why is the date March 10th, 1876, important?", correct: "It was the day of the first successful telephone transmission, where Bell spoke the first words to his assistant, Mr. Watson.", wrong: ["It was when the first telegraph message was sent across the Atlantic Ocean.", "It marked the patent filing date for the first radio broadcasting system.", "It was the day the first electric light bulb was demonstrated publicly."], questionTranslation: "Почему дата 10 марта 1876 года важна?", answerTranslation: "В этот день состоялась первая успешная передача по телефону: Белл произнёс первые слова ассистенту Ватсону."),
    Question(question: "What is Alfred Nobel famous for? What is his most prominent invention?", correct: "He is famous for establishing the Nobel Prize. His most prominent invention was dynamite.", wrong: ["He invented the first steam locomotive and founded the Nobel Railway Company.", "He created the first electric generator and established the Energy Prize.", "He discovered penicillin and left his fortune for medical research awards."], questionTranslation: "Чем знаменит Альфред Нобель? Какое его главное изобретение?", answerTranslation: "Известен учреждением Нобелевской премии. Его главное изобретение — динамит."),
    Question(question: "How was the Nobel Prize established?", correct: "It was established through the will of Alfred Nobel, who left his fortune in a trust to fund the awards.", wrong: ["The Swedish Parliament created it to honor the greatest scientists of each century.", "It was founded by a group of wealthy industrialists in memory of Nobel.", "The United Nations established it using donations from Nobel's family members."], questionTranslation: "Как была учреждена Нобелевская премия?", answerTranslation: "По завещанию Альфреда Нобеля, который оставил своё состояние в фонд для премий."),
    Question(question: "Describe the selection process for the Nobel Prize winners.", correct: "Winners are selected for making outstanding contributions or discoveries in their fields during the preceding year.", wrong: ["Winners are chosen by popular vote from people around the world each December.", "A computer algorithm selects winners based on the number of citations they have.", "Winners must nominate themselves and present their work to a public jury."], questionTranslation: "Опишите процесс отбора лауреатов Нобелевской премии.", answerTranslation: "Победителей выбирают за выдающиеся достижения или открытия в своей области за предыдущий год."),
    Question(question: "What fields is the Nobel Prize awarded in?", correct: "Physics, Chemistry, Medicine (Physiology), Literature, Economics, and Peace.", wrong: ["Mathematics, Biology, Engineering, Art, Music, and International Relations.", "Physics, Sports, Cooking, Fashion, Technology, and Environmental Protection.", "Medicine, Architecture, Film, Dance, Philosophy, and Human Rights."], questionTranslation: "В каких областях вручается Нобелевская премия?", answerTranslation: "Физика, химия, медицина (физиология), литература, экономика и премия мира."),
    Question(question: "What is the maximum number of laureates that can receive a single award, and what is the exception?", correct: "The maximum is three individuals. The exception is the Peace Prize, which can be awarded to entire organizations.", wrong: ["The maximum is five people, with no exceptions for any category.", "Only one person can win per category, but organizations can win two categories.", "The maximum is ten people, and the Literature Prize can go to publishing houses."], questionTranslation: "Какое максимальное число лауреатов может получить одну премию и какое исключение?", answerTranslation: "Максимум три человека. Исключение — премия мира, которую могут получить целые организации."),
    Question(question: "What are some examples of famous Nobel laureates mentioned in the video?", correct: "Ernest Hemingway (Literature), Alexander Fleming (Medicine), Albert Einstein (Physics), and Marie Curie (Physics and Chemistry).", wrong: ["William Shakespeare (Literature), Louis Pasteur (Medicine), Isaac Newton (Physics).", "Mark Twain (Literature), Charles Darwin (Medicine), Galileo Galilei (Physics).", "Oscar Wilde (Literature), Sigmund Freud (Medicine), Stephen Hawking (Physics)."], questionTranslation: "Какие примеры знаменитых нобелевских лауреатов упомянуты в видео?", answerTranslation: "Эрнест Хемингуэй (литература), Александр Флеминг (медицина), Альберт Эйнштейн (физика), Мария Кюри (физика и химия)."),
    Question(question: "What is Alan Turing famous for?", correct: "He is a pioneer of computer science who helped break the Enigma code and laid the foundation for AI and modern computing.", wrong: ["He invented the first internet protocol and created the World Wide Web.", "He was the first person to walk on the moon and designed space computers.", "He discovered electricity and invented the first electric power plant."], questionTranslation: "Чем знаменит Алан Тьюринг?", answerTranslation: "Пионер информатики: взломал код «Энигмы» и заложил основы ИИ и современных вычислений."),
    Question(question: "What does the concept of the Turing Machine refer to?", correct: "It is a theoretical model that defines how computers process information using algorithms.", wrong: ["It is a physical machine that can predict the future using mathematical calculations.", "It refers to a special typewriter that could encode and decode secret messages.", "It is a robot that can play chess better than any human in the world."], questionTranslation: "Что означает понятие «Машина Тьюринга»?", answerTranslation: "Теоретическая модель, описывающая, как компьютеры обрабатывают информацию с помощью алгоритмов."),
    Question(question: "What is the Turing Test?", correct: "A test that measures a machine's ability to exhibit intelligent behavior indistinguishable from a human.", wrong: ["A test that measures how fast a computer can solve mathematical equations.", "A security test used to verify that a user is human and not a robot online.", "A test that determines the IQ level of artificial intelligence systems."], questionTranslation: "Что такое тест Тьюринга?", answerTranslation: "Тест, определяющий, способна ли машина вести себя так разумно, что её не отличить от человека."),
    Question(question: "What do you know about the Turing Award?", correct: "It is called the 'Nobel Prize of Computing' and is awarded by the ACM for groundbreaking contributions to computer science.", wrong: ["It is given to the best video game developers by the Gaming Association annually.", "It rewards the fastest programmers in competitive coding championships worldwide.", "It is an award for the most beautiful website design on the internet each year."], questionTranslation: "Что вы знаете о премии Тьюринга?", answerTranslation: "«Нобелевская премия по информатике», вручается ACM за прорывные достижения в области компьютерных наук."),
    Question(question: "What do you know about the creation of the original recipe for the Coca-Cola drink and the shroud of mystery around it?", correct: "It was created by John Pemberton in 1886. The 'mystery' is largely a marketing strategy used to generate attention.", wrong: ["It was discovered by accident in a laboratory in 1900 by a French chemist.", "The recipe was brought from Italy by immigrants in the 1700s and kept secret.", "It was invented by a pharmacist in London and sold to Americans in 1920."], questionTranslation: "Что вы знаете о создании оригинального рецепта Coca-Cola и ореоле тайны вокруг него?", answerTranslation: "Напиток создал Джон Пембертон в 1886 году. «Тайна» — это во многом маркетинговый ход."),
    Question(question: "Where is the Coca-Cola formula kept now? What security measures protect it?", correct: "It is kept in a high-tech vault at the World of Coca-Cola in Atlanta, protected by palm scanners, code pads, and thick steel doors.", wrong: ["It is stored in a Swiss bank vault with armed guards watching it 24/7.", "The formula is memorized by three people and never written down anywhere.", "It is kept in a underground bunker in Washington with military protection."], questionTranslation: "Где сейчас хранится формула Coca-Cola? Какие меры безопасности её защищают?", answerTranslation: "В высокотехнологичном хранилище в «World of Coca-Cola» в Атланте. Защита: сканеры ладони, кодовые панели, стальные двери."),
    Question(question: "What is the purpose of creating a shroud of mystery around the Coca-Cola formula?", correct: "To create a brand legend that generates curiosity and keeps the product famous.", wrong: ["To prevent competitors from copying the recipe which changes every month.", "Because the ingredients are actually dangerous and need to be hidden from public.", "To comply with government regulations about food industry trade secrets."], questionTranslation: "Какова цель создания ореола тайны вокруг формулы Coca-Cola?", answerTranslation: "Чтобы создать легенду бренда, вызвать интерес и поддерживать популярность продукта."),
    Question(question: "What was the industrial revolution in the USA based on according to the text?", correct: "It was founded on intellectual property smuggled out of England.", wrong: ["It was based on inventions created entirely by American scientists from scratch.", "It started when the USA imported all its machinery from France and Germany.", "It was funded by wealthy investors who bought patents from Asian countries."], questionTranslation: "На чём основывалась промышленная революция в США согласно тексту?", answerTranslation: "На интеллектуальной собственности, вывезенной контрабандой из Англии."),
    Question(question: "How did the invention of the water-powered spinning frame change the country's industrial sector?", correct: "It increased the production of cotton goods tenfold and led to the creation of many new factories.", wrong: ["It replaced all manual labor with robots and eliminated the need for workers.", "It was used only for making silk and had no impact on the cotton industry.", "It decreased production but improved the quality of handmade goods significantly."], questionTranslation: "Как изобретение водяной прядильной рамы изменило промышленный сектор страны?", answerTranslation: "Увеличило производство хлопка в 10 раз и дало толчок к строительству множества новых фабрик."),
    Question(question: "What laws did the British Parliament pass in 1774 to protect the country's industrial secrets?", correct: "They passed laws prohibiting engineers and mechanics from traveling abroad.", wrong: ["They banned the export of all British-made machinery to foreign countries.", "They imposed heavy taxes on anyone who shared industrial knowledge verbally.", "They required all factory workers to sign lifetime confidentiality agreements."], questionTranslation: "Какие законы принял британский парламент в 1774 году для защиты промышленных секретов?", answerTranslation: "Законы, запрещающие инженерам и механикам выезжать за границу."),
    Question(question: "How did the technology of the water frame appear in the USA?", correct: "Samuel Slater memorized the plans and sailed to America in 1789 to rebuild the machine there.", wrong: ["The British government sold the blueprints to American businessmen for gold.", "An American spy stole the actual machine and shipped it in pieces to Boston.", "The technology was independently invented by American engineers from scratch."], questionTranslation: "Как технология водяной рамы появилась в США?", answerTranslation: "Сэмюэл Слейтер запомнил чертежи и в 1789 году уплыл в Америку, чтобы воссоздать машину там."),
    Question(question: "What is the Rhode Island System?", correct: "A model for factory life that included tenements for workers and a company store built around the mill.", wrong: ["A banking system created to fund industrial development in the northeastern states.", "A transportation network connecting all major factories via railroads in Rhode Island.", "An education program teaching workers how to operate machinery safely and efficiently."], questionTranslation: "Что такое система Род-Айленда?", answerTranslation: "Модель фабричной жизни: рабочие общежития и фирменный магазин при фабрике."),
    Question(question: "What did Samuel Slater and Francis Lowell have in common?", correct: "Both memorized industrial plans in England and 'stole' them to start successful manufacturing industries in the USA.", wrong: ["Both were British citizens who legally sold their inventions to the American government.", "Both invented the steam engine and founded railway companies in the United States.", "Both worked for the British Parliament and shared secrets with American diplomats."], questionTranslation: "Что было общего у Сэмюэла Слейтера и Фрэнсиса Лоуэлла?", answerTranslation: "Оба запомнили промышленные чертежи в Англии и «украли» их, чтобы запустить производство в США."),
    Question(question: "What does *know-how* refer to?", correct: "It refers to practical knowledge or expertise on how to do something effectively, especially in technology or business.", wrong: ["It is a legal term meaning the ownership of patented inventions and designs.", "It refers to knowing who to contact in order to get information about anything.", "It means having a university degree in engineering or business administration."], questionTranslation: "Что означает термин *know-how*?", answerTranslation: "Практические знания или экспертиза, как эффективно что-то сделать, особенно в технологиях или бизнесе."),
    Question(question: "Why is it important to take all advertisement with a grain of salt?", correct: "Because advertisements are often based on exaggerated claims or 'shrouds of mystery' designed purely for marketing.", wrong: ["Because all advertisements are illegal and should be ignored by consumers.", "Because companies are required by law to lie in their advertising campaigns.", "Because advertisements always contain hidden messages that control your mind."], questionTranslation: "Почему важно относиться ко всей рекламе с долей скептицизма?", answerTranslation: "Потому что реклама часто основана на преувеличениях или «ореоле тайны», созданных для маркетинга."),
    Question(question: "What is the purpose of smuggling? Why does it still exist today?", correct: "The purpose is to gain illegal access to restricted goods or secrets for profit. It exists because of high demand and the desire for competitive advantages.", wrong: ["Smuggling is only about transporting people across borders for tourism purposes.", "It exists because governments want to test their border security systems regularly.", "The purpose is to help poor countries get technology from wealthy nations freely."], questionTranslation: "Какова цель контрабанды? Почему она существует и сегодня?", answerTranslation: "Цель — незаконный доступ к ограниченным товарам или секретам ради прибыли. Существует из-за высокого спроса."),
    Question(question: "What is the brain drain and why does it happen?", correct: "It is the emigration of highly trained or intelligent people from a particular country, usually due to better job opportunities or living conditions elsewhere.", wrong: ["It is a medical condition where people lose memory after moving to a new country.", "It refers to the loss of data when computers are transported across borders.", "It happens when a country's education system stops producing qualified graduates."], questionTranslation: "Что такое утечка мозгов и почему она происходит?", answerTranslation: "Эмиграция высококвалифицированных специалистов из страны, обычно из-за лучших условий работы и жизни."),
    Question(question: "What are trade secrets?", correct: "Confidential business information (like the Coke formula or Google's search algorithms) that provides an edge over competitors.", wrong: ["They are government documents classified as top secret and hidden from the public.", "Trade secrets are special products sold only in international trade markets.", "They refer to the secret handshake used by businessmen to recognize each other."], questionTranslation: "Что такое коммерческая тайна?", answerTranslation: "Конфиденциальная бизнес-информация (как формула Coca-Cola или алгоритмы Google), дающая преимущество."),
    Question(question: "Name Top Russian inventions that changed the world.", correct: "Common examples include the Periodic Table (Mendeleev), Radio (Popov), and the First Satellite/Sputnik (Korolev).", wrong: ["The steam engine (Lomonosov), the telephone (Pavlov), and the Internet (Yandex).", "The light bulb (Kurchatov), the airplane (Gagarin), and penicillin (Mechnikov).", "The computer (Vavilov), the laser (Landau), and the World Wide Web (Runet)."], questionTranslation: "Назовите главные российские изобретения, изменившие мир.", answerTranslation: "Периодическая таблица (Менделеев), радио (Попов), первый спутник (Королёв).")
]


// MARK: - Answer Button
struct AnswerBtn: View {
    let answer: String
    let isSelected: Bool
    let showResult: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let action: () -> Void

    var bgColor: Color { Color.white }
    
    var glowColor: Color? {
        if showResult {
            if isCorrect { return Color.green }
            if isWrong { return Color.red }
        }
        return nil
    }
    
    var borderColor: Color {
        if showResult {
            if isCorrect { return Color.green }
            if isWrong { return Color.red }
        }
        return Color.gray.opacity(0.3)
    }
    
    var body: some View {
        Button(action: action) {
            Text(answer).font(.body).fontWeight(isCorrect || isWrong ? .semibold : .regular)
                .multilineTextAlignment(.leading).foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(16).background(bgColor)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 2.5))
                .cornerRadius(12)
                .shadow(color: glowColor ?? Color.clear, radius: isCorrect || isWrong ? 12 : 0, x: 0, y: 0)
        }.disabled(showResult)
    }
}

// MARK: - Results View
struct ResultsView: View {
    let score: Int
    let total: Int
    let onRestart: () -> Void
    
    var pct: Int { Int((Double(score) / Double(total)) * 100) }
    
    var msg: String {
        let lm = LanguageManager.shared
        if lm.isRussian {
            if pct >= 90 { return "Отлично! Ты готов к контрольной! 🌟" }
            if pct >= 70 { return "Хорошо! Ещё немного повторить! 👍" }
            if pct >= 50 { return "Неплохо, но стоит подучить! 📚" }
            return "Нужно ещё подготовиться! 💪"
        } else {
            if pct >= 90 { return "Excellent! You're ready for the test! 🌟" }
            if pct >= 70 { return "Good! A little more practice! 👍" }
            if pct >= 50 { return "Not bad, but keep studying! 📚" }
            return "Need more preparation! 💪"
        }
    }
    
    var msgColor: Color {
        if pct >= 90 { return Color.green }
        if pct >= 70 { return Color.blue }
        if pct >= 50 { return Color.orange }
        return Color.red
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            Text("🎉").font(.system(size: 80))
            Text(LanguageManager.shared.isRussian ? "Тест завершён!" : "Quiz Complete!").font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
            VStack(spacing: 15) {
                HStack {
                    Text(LanguageManager.shared.isRussian ? "Правильных ответов:" : "Correct answers:").font(.title3).foregroundColor(.white)
                    Spacer()
                    Text("\(score) / \(total)").font(.title2).fontWeight(.bold).foregroundColor(.white)
                }.padding().background(Color.white.opacity(0.15)).cornerRadius(12)
                HStack {
                    Text(LanguageManager.shared.isRussian ? "Процент:" : "Percentage:").font(.title3).foregroundColor(.white)
                    Spacer()
                    Text("\(pct)%").font(.title2).fontWeight(.bold).foregroundColor(.white)
                }.padding().background(Color.white.opacity(0.15)).cornerRadius(12)
            }.padding(.horizontal, 40)
            Text(msg).font(.title2).fontWeight(.semibold).foregroundColor(msgColor).padding()
                .frame(maxWidth: .infinity).background(Color.white).cornerRadius(12).padding(.horizontal, 40)
            Spacer()
            Button(action: onRestart) {
                Text(LanguageManager.shared.isRussian ? "🔄 Пройти заново" : "🔄 Restart").font(.title2).fontWeight(.bold).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.white.opacity(0.2)).cornerRadius(12)
            }.padding(.horizontal, 40).padding(.bottom, 50)
        }
    }
}

// MARK: - Quiz View
struct QuizView: View {
    let questions: [Question]?
    let onBack: () -> Void
    @StateObject private var vm: QuizViewModel
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
    
    init(questions: [Question]? = nil, onBack: @escaping () -> Void) {
        self.questions = questions
        self.onBack = onBack
        _vm = StateObject(wrappedValue: QuizViewModel(questions: questions))
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.23, green: 0.49, blue: 0.96), Color(red: 0.55, green: 0.36, blue: 0.64)]), startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()

            if vm.showResults {
                ResultsView(score: vm.score, total: vm.shuffledQuestions.count, onRestart: vm.restart)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Button(action: onBack) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.left")
                                Text(langManager.isRussian ? "Назад" : "Back")
                            }
                            .font(.body).fontWeight(.bold).foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.white.opacity(0.25)).cornerRadius(10)
                        }.buttonStyle(.plain)
                        Spacer()
                        Text("📝").font(.title3)
                        Spacer()
                        Menu {
                            ForEach(AppLanguage.allCases, id: \.self) { lang in
                                Button(action: { langManager.currentLanguage = lang }) {
                                    Text(lang.displayName)
                                    if langManager.currentLanguage == lang { Image(systemName: "checkmark") }
                                }
                            }
                        } label: {
                            Text(langManager.currentLanguage.displayName)
                                .font(.body).fontWeight(.medium).foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.white.opacity(0.2)).cornerRadius(8)
                        }.buttonStyle(.plain)
                    }.padding(.horizontal, 24).padding(.top, 12)

                    VStack(spacing: 12) {
                        HStack {
                            Text("\(langManager.isRussian ? "Вопрос" : "Question") \(vm.currentIndex + 1) / \(vm.shuffledQuestions.count)").font(.subheadline).foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Text("\(langManager.isRussian ? "Счёт" : "Score"): \(vm.score)").font(.subheadline).fontWeight(.bold).foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 6).background(Color.white.opacity(0.2)).cornerRadius(15)
                        }.padding(.horizontal, 24).padding(.top, 8)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.white.opacity(0.3)).frame(height: 6).cornerRadius(3)
                                Rectangle().fill(Color.white).frame(width: geo.size.width * vm.progress, height: 6).cornerRadius(3).animation(.easeInOut(duration: 0.3), value: vm.progress)
                            }
                        }.frame(height: 6).padding(.horizontal, 24).padding(.bottom, 16)
                    }
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Text(vm.currentQuestion.question).font(.title2).fontWeight(.semibold).multilineTextAlignment(.center).foregroundColor(.primary).padding(24).frame(maxWidth: .infinity).background(Color(NSColor.controlBackgroundColor)).cornerRadius(16).shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            if vm.answered && vm.selectedAnswer != vm.currentQuestion.correct && settings.showTranslations {
                                if let qTrans = vm.currentQuestion.questionTranslation {
                                    Text("🇷🇺 \(qTrans)").font(.body).foregroundColor(.primary).padding(12).frame(maxWidth: .infinity).background(Color.white).cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 2))
                                }
                            }
                        }.padding(.horizontal, 24).padding(.top, 20)

                        VStack(spacing: 10) {
                            ForEach(vm.currentAnswers, id: \.self) { ans in
                                VStack(spacing: 4) {
                                    let userCorrect = vm.selectedAnswer == vm.currentQuestion.correct
                                    let showGreenBorder = vm.answered && ans == vm.currentQuestion.correct && !userCorrect
                                    let showRedBorder = vm.answered && ans == vm.selectedAnswer && !userCorrect
                                    let showOnlyGreen = vm.answered && ans == vm.selectedAnswer && userCorrect

                                    AnswerBtn(
                                        answer: ans, isSelected: vm.selectedAnswer == ans,
                                        showResult: vm.answered, isCorrect: showGreenBorder || showOnlyGreen,
                                        isWrong: showRedBorder
                                    ) { if !vm.answered { vm.pick(ans) } }
                                    
                                    if vm.answered && ans == vm.currentQuestion.correct && !userCorrect && settings.showTranslations {
                                        if let aTrans = vm.currentQuestion.answerTranslation {
                                            Text("🇷🇺 \(aTrans)").font(.caption).foregroundColor(.primary).padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Color.white).cornerRadius(8)
                                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green, lineWidth: 1.5))
                                        }
                                    }
                                }
                            }
                        }.padding(.horizontal, 24)

                        if vm.answered {
                            Button(action: vm.nextQ) {
                                Text(vm.currentIndex < vm.shuffledQuestions.count - 1 ? (langManager.isRussian ? "Следующий вопрос →" : "Next question →") : (langManager.isRussian ? "Показать результат" : "Show results"))
                                    .font(.title3).fontWeight(.bold).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                                    .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.23, green: 0.49, blue: 0.96), Color(red: 0.55, green: 0.36, blue: 0.64)]), startPoint: .leading, endPoint: .trailing)).cornerRadius(12)
                            }.padding(.horizontal, 24).padding(.top, 10)
                        }
                        Spacer(minLength: 30)
                    }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Quiz ViewModel
class QuizViewModel: ObservableObject {
    @Published var currentIndex = 0
    @Published var score = 0
    @Published var answered = false
    @Published var showResults = false
    @Published var selectedAnswer: String? = nil
    @Published var shuffledQuestions: [Question] = []
    @Published var currentAnswers: [String] = []
    
    private var customQuestions: [Question]?

    init(questions: [Question]? = nil) {
        customQuestions = questions
        shuffle()
    }

    var currentQuestion: Question { shuffledQuestions[currentIndex] }
    var progress: Double { Double(currentIndex + 1) / Double(shuffledQuestions.count) }

    func shuffle() {
        if let custom = customQuestions {
            shuffledQuestions = custom.shuffled()
        } else {
            shuffledQuestions = QuestionFileManager.shared.loadQuestions().shuffled()
        }
        currentIndex = 0; score = 0
        loadCurrentAnswers()
    }
    
    func loadCurrentAnswers() { currentAnswers = currentQuestion.allAnswers }
    
    func pick(_ a: String) { selectedAnswer = a; answered = true; if a == currentQuestion.correct { score += 1 } }
    
    func nextQ() {
        if currentIndex < shuffledQuestions.count - 1 {
            currentIndex += 1; selectedAnswer = nil; answered = false
            loadCurrentAnswers()
        } else { showResults = true }
    }
    
    func restart() {
        currentIndex = 0; score = 0; selectedAnswer = nil; answered = false; showResults = false
        shuffle()
    }
}

// MARK: - Add Question View
struct AddQuestionView: View {
    let onBack: () -> Void
    @State private var questionText = ""
    @State private var correctAnswer = ""
    @State private var wrong1 = ""
    @State private var wrong2 = ""
    @State private var wrong3 = ""
    @State private var translationText = ""
    @State private var showSuccess = false
    @ObservedObject private var aiManager = AIManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    
    var canSave: Bool {
        !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !wrong1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !wrong2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !wrong3.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.23, green: 0.49, blue: 0.96), Color(red: 0.55, green: 0.36, blue: 0.64)]), startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                            Text(LanguageManager.shared.isRussian ? "Назад" : "Back")
                        }
                        .font(.body).fontWeight(.bold).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.white.opacity(0.25)).cornerRadius(10)
                    }.buttonStyle(.plain)
                    Spacer()
                    Text(LanguageManager.shared.isRussian ? "➕ Добавить вопрос" : "➕ Add Question").font(.title3).fontWeight(.bold).foregroundColor(.white)
                    Spacer()
                    Text(" ").frame(width: 100)
                }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LanguageManager.shared.isRussian ? "Вопрос:" : "Question:").font(.headline).foregroundColor(.white)
                            TextEditor(text: $questionText).frame(height: 80).padding(10).background(Color.white).cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.5), lineWidth: 2))
                        }.padding(.horizontal, 30).padding(.top, 16)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(LanguageManager.shared.isRussian ? "✅ Правильный ответ:" : "✅ Correct answer:").font(.headline).foregroundColor(.white)
                            TextEditor(text: $correctAnswer).frame(height: 60).padding(10).background(Color.white).cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.5), lineWidth: 2))
                        }.padding(.horizontal, 30)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(LanguageManager.shared.isRussian ? "❌ Неправильные ответы:" : "❌ Wrong answers:").font(.headline).foregroundColor(.white)
                            VStack(spacing: 8) {
                                HStack { Text("1.").foregroundColor(.white).frame(width: 25, alignment: .trailing); TextField("", text: $wrong1).textFieldStyle(.plain).padding(10).background(Color.white).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.4), lineWidth: 2)) }
                                HStack { Text("2.").foregroundColor(.white).frame(width: 25, alignment: .trailing); TextField("", text: $wrong2).textFieldStyle(.plain).padding(10).background(Color.white).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.4), lineWidth: 2)) }
                                HStack { Text("3.").foregroundColor(.white).frame(width: 25, alignment: .trailing); TextField("", text: $wrong3).textFieldStyle(.plain).padding(10).background(Color.white).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.4), lineWidth: 2)) }
                            }
                            // AI Generate button
                            Button(action: generateWithAI) {
                                HStack {
                                    if aiManager.isGenerating {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                    }
                                    Text(aiManager.isGenerating ? (LanguageManager.shared.isRussian ? "Генерация..." : "Generating...") : (LanguageManager.shared.isRussian ? "✨ Сгенерировать ИИ" : "✨ Generate with AI"))
                                }
                                .font(.body).fontWeight(.medium).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Group {
                                    if settings.apiKey.isEmpty { Color.gray }
                                    else { LinearGradient(gradient: Gradient(colors: [Color.orange, Color.red]), startPoint: .leading, endPoint: .trailing) }
                                })
                                .cornerRadius(10)
                            }.disabled(aiManager.isGenerating || settings.apiKey.isEmpty || questionText.isEmpty || correctAnswer.isEmpty).padding(.top, 8)
                            
                            if let errorMsg = aiManager.errorMessage {
                                Text(errorMsg).font(.caption).foregroundColor(.red).padding(8).frame(maxWidth: .infinity).background(Color.red.opacity(0.1)).cornerRadius(8)
                            }
                        }.padding(.horizontal, 30)
                        
                        if settings.showTranslationField {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LanguageManager.shared.isRussian ? "🇷 Перевод на русский (необязательно):" : "🇷 Russian translation (optional):").font(.headline).foregroundColor(.white)
                                TextEditor(text: $translationText).frame(height: 50).padding(10).background(Color.white).cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.4), lineWidth: 2))
                            }.padding(.horizontal, 30)
                        }

                        Button(action: saveQuestion) {
                            Text(LanguageManager.shared.isRussian ? "💾 Сохранить вопрос" : "💾 Save Question")
                                .font(.title3).fontWeight(.bold).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(canSave ? Color.green : Color.gray).cornerRadius(12)
                        }.disabled(!canSave).padding(.horizontal, 30).padding(.top, 10)

                        if showSuccess {
                            Text(LanguageManager.shared.isRussian ? "✅ Вопрос сохранён!" : "✅ Question saved!").font(.title3).fontWeight(.bold).foregroundColor(.green)
                                .padding().background(Color.green.opacity(0.15)).cornerRadius(10)
                        }
                        Spacer(minLength: 20)
                    }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func generateWithAI() {
        let q = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty && !a.isEmpty else { return }
        
        aiManager.generateWrongAnswers(question: q, correctAnswer: a) { answers in
            if let answers = answers, answers.count >= 3 {
                wrong1 = answers[0]
                wrong2 = answers[1]
                wrong3 = answers[2]
            }
        }
    }
    
    func saveQuestion() {
        let q = Question(
            question: questionText.trimmingCharacters(in: .whitespacesAndNewlines),
            correct: correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines),
            wrong: [wrong1, wrong2, wrong3].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            answerTranslation: translationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : translationText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        QuestionFileManager.shared.addQuestion(q)
        showSuccess = true
        questionText = ""; correctAnswer = ""; wrong1 = ""; wrong2 = ""; wrong3 = ""; translationText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSuccess = false }
    }
}

// MARK: - Manage Questions View
struct ManageQuestionsView: View {
    let onBack: () -> Void
    @State private var questions: [Question] = []
    @State private var showDeleteAlert = false
    @State private var questionToDelete: Question?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                        Text(LanguageManager.shared.isRussian ? "Назад" : "Back")
                    }
                    .font(.body).fontWeight(.bold).foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.white.opacity(0.25)).cornerRadius(10)
                }.buttonStyle(.plain)
                Spacer()
                Text(LanguageManager.shared.isRussian ? "📋 Управление вопросами" : "📋 Manage Questions").font(.title3).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button(action: { QuestionFileManager.shared.resetToDefaults(); questions = QuestionFileManager.shared.loadQuestions() }) {
                    Text(LanguageManager.shared.isRussian ? "Сбросить" : "Reset").font(.body).fontWeight(.medium).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8).background(Color.orange.opacity(0.8)).cornerRadius(10)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)
                .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.23, green: 0.49, blue: 0.96), Color(red: 0.55, green: 0.36, blue: 0.64)]), startPoint: .leading, endPoint: .trailing))

            Text("\(LanguageManager.shared.isRussian ? "Всего вопросов" : "Total questions"): \(questions.count)").font(.title3).fontWeight(.medium).foregroundColor(.primary).padding(.top, 10)
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(questions) { q in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(q.question).font(.body).fontWeight(.medium).foregroundColor(.primary).lineLimit(2)
                                Text("✅ \(q.correct)").font(.caption).foregroundColor(.green).lineLimit(1)
                            }
                            Spacer()
                            Button(action: { questionToDelete = q; showDeleteAlert = true }) { Text("🗑️").font(.title2) }.buttonStyle(.plain)
                        }.padding(12).background(Color(NSColor.controlBackgroundColor)).cornerRadius(10)
                    }
                }.padding(.horizontal, 24).padding(.top, 10)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { questions = QuestionFileManager.shared.loadQuestions() }
            .alert(isPresented: $showDeleteAlert) {
                Alert(title: Text(LanguageManager.shared.isRussian ? "Удалить вопрос?" : "Delete question?"),
                      message: Text(LanguageManager.shared.isRussian ? "Этот вопрос будет удалён навсегда." : "This question will be deleted permanently."),
                      primaryButton: .destructive(Text(LanguageManager.shared.isRussian ? "Удалить" : "Delete")) {
                        if let q = questionToDelete { QuestionFileManager.shared.deleteQuestion(id: q.id); questions = QuestionFileManager.shared.loadQuestions() }
                      }, secondaryButton: .cancel())
            }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    let onBack: () -> Void
    @ObservedObject var langManager = LanguageManager.shared
    @ObservedObject var settings = SettingsManager.shared
    @State private var apiKeyInput = ""
    @State private var keySaved = false
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.23, green: 0.49, blue: 0.96), Color(red: 0.55, green: 0.36, blue: 0.64)]), startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                            Text(langManager.isRussian ? "Назад" : "Back")
                        }.font(.body).fontWeight(.bold).foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8).background(Color.white.opacity(0.25)).cornerRadius(10)
                    }.buttonStyle(.plain)
                    Spacer()
                    Text(langManager.isRussian ? "⚙️ Настройки" : "⚙️ Settings").font(.title3).fontWeight(.bold).foregroundColor(.white)
                    Spacer()
                    Text(" ").frame(width: 100)
                }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)

                VStack(spacing: 20) {
                    // Language selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text(langManager.isRussian ? "🌐 Язык интерфейса" : "🌐 Interface Language").font(.headline).foregroundColor(.white)
                        HStack(spacing: 12) {
                            ForEach(AppLanguage.allCases, id: \.self) { lang in
                                Button(action: { langManager.currentLanguage = lang }) {
                                    Text(lang.displayName)
                                        .font(.body).fontWeight(.medium)
                                        .foregroundColor(langManager.currentLanguage == lang ? .white : .primary)
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(langManager.currentLanguage == lang ? Color.blue : Color.white)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(langManager.currentLanguage == lang ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2))
                                }.buttonStyle(.plain)
                            }
                        }
                    }.padding(.horizontal, 30).padding(.top, 20)

                    // Translation toggle
                    VStack(alignment: .leading, spacing: 12) {
                        Text(langManager.isRussian ? "📖 Переводы" : "📖 Translations").font(.headline).foregroundColor(.white)
                        HStack {
                            Text(langManager.isRussian ? "Показывать перевод после неправильного ответа" : "Show translation after wrong answer")
                                .font(.body).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Toggle("", isOn: $settings.showTranslations).labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                        }.padding(16).background(Color.white.opacity(0.15)).cornerRadius(12)
                        
                        HStack {
                            Text(langManager.isRussian ? "Поле перевода при добавлении вопроса" : "Translation field when adding question")
                                .font(.body).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            Toggle("", isOn: $settings.showTranslationField).labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                        }.padding(16).background(Color.white.opacity(0.15)).cornerRadius(12)
                    }.padding(.horizontal, 30)

                    // AI API Key
                    VStack(alignment: .leading, spacing: 12) {
                        Text(langManager.isRussian ? "🤖 ИИ для генерации ответов" : "🤖 AI for Answer Generation").font(.headline).foregroundColor(.white)
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "key.fill").foregroundColor(.orange)
                                Text(langManager.isRussian ? "API ключ OpenRouter:" : "OpenRouter API Key:").font(.subheadline).foregroundColor(.white.opacity(0.8))
                            }
                            SecureField("sk-or-...", text: $apiKeyInput)
                                .textFieldStyle(.plain)
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.5), lineWidth: 2))
                            
                            HStack {
                                Button(action: saveApiKey) {
                                    HStack {
                                        Image(systemName: keySaved ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                                        Text(keySaved ? (langManager.isRussian ? "Сохранено ✓" : "Saved ✓") : (langManager.isRussian ? "Сохранить ключ" : "Save Key"))
                                    }
                                    .font(.body).fontWeight(.medium).foregroundColor(.white)
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(keySaved ? Color.green : Color.orange)
                                    .cornerRadius(10)
                                }
                                
                                if !settings.apiKey.isEmpty {
                                    Button(action: clearApiKey) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color.red.opacity(0.8))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            
                            if keySaved {
                                Text(langManager.isRussian ? "✅ Ключ сохранён и готов к использованию" : "✅ Key saved and ready to use")
                                    .font(.caption).foregroundColor(.green).fontWeight(.medium)
                            }
                            
                            Text(langManager.isRussian ? "Получите бесплатный ключ на openrouter.ai" : "Get free key at openrouter.ai")
                                .font(.caption).foregroundColor(.white.opacity(0.6))
                        }.padding(16).background(Color.white.opacity(0.15)).cornerRadius(12)
                    }.padding(.horizontal, 30)

                    Spacer()
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { apiKeyInput = settings.apiKey; keySaved = !settings.apiKey.isEmpty }
    }
    
    func saveApiKey() {
        settings.apiKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        keySaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            keySaved = false
        }
    }
    
    func clearApiKey() {
        settings.apiKey = ""
        apiKeyInput = ""
        keySaved = false
    }
}

// MARK: - Tests View (Create & Manage Tests)
struct TestsView: View {
    let onBack: () -> Void
    let onStartTest: ([Question]) -> Void
    @ObservedObject var langManager = LanguageManager.shared
    @State private var tests: [QuizTest] = []
    @State private var showCreateTest = false
    @State private var showDeleteAlert = false
    @State private var testToDelete: QuizTest?
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.23, green: 0.49, blue: 0.96), Color(red: 0.55, green: 0.36, blue: 0.64)]), startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left")
                            Text(langManager.isRussian ? "Назад" : "Back")
                        }.font(.body).fontWeight(.bold).foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8).background(Color.white.opacity(0.25)).cornerRadius(10)
                    }.buttonStyle(.plain)
                    Spacer()
                    Text(langManager.isRussian ? "📚 Мои тесты" : "📚 My Tests").font(.title3).fontWeight(.bold).foregroundColor(.white)
                    Spacer()
                    Button(action: { showCreateTest = true }) {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.white)
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)
                
                if tests.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Text("📚").font(.system(size: 60))
                        Text(langManager.isRussian ? "Нет созданных тестов" : "No tests created yet").font(.title2).foregroundColor(.white.opacity(0.8))
                        Text(langManager.isRussian ? "Нажмите + чтобы создать тест" : "Tap + to create a test").font(.body).foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(tests) { test in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(test.name).font(.title3).fontWeight(.semibold).foregroundColor(.primary)
                                        Text("\(test.questionIds.count) \(langManager.isRussian ? "вопросов" : "questions")").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(action: { startTest(test) }) {
                                        Text(langManager.isRussian ? "Начать" : "Start").font(.body).fontWeight(.medium).foregroundColor(.white)
                                            .padding(.horizontal, 16).padding(.vertical, 8)
                                            .background(Color.blue).cornerRadius(8)
                                    }.buttonStyle(.plain)
                                    Button(action: { testToDelete = test; showDeleteAlert = true }) {
                                        Image(systemName: "trash").font(.title2).foregroundColor(.red)
                                    }.buttonStyle(.plain)
                                }.padding(16).background(Color(NSColor.controlBackgroundColor)).cornerRadius(12)
                            }
                        }.padding(.horizontal, 24).padding(.top, 10)
                    }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { tests = TestManager.shared.loadTests() }
            .sheet(isPresented: $showCreateTest) {
                CreateTestView(onDismiss: {
                    showCreateTest = false
                    tests = TestManager.shared.loadTests()
                })
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(title: Text(langManager.isRussian ? "Удалить тест?" : "Delete test?"),
                      message: Text(testToDelete?.name ?? ""),
                      primaryButton: .destructive(Text(langManager.isRussian ? "Удалить" : "Delete")) {
                        if let t = testToDelete { TestManager.shared.deleteTest(id: t.id); tests = TestManager.shared.loadTests() }
                      }, secondaryButton: .cancel())
            }
    }
    
    func startTest(_ test: QuizTest) {
        let questions = TestManager.shared.getQuestions(for: test)
        if !questions.isEmpty {
            onStartTest(questions)
        }
    }
}

// MARK: - Create Test View
struct CreateTestView: View {
    let onDismiss: () -> Void
    @ObservedObject var langManager = LanguageManager.shared
    @State private var testName = ""
    @State private var allQuestions: [Question] = []
    @State private var selectedIds: Set<UUID> = []
    @State private var randomCount = 10
    @State private var showRandomPicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text(langManager.isRussian ? "Название теста:" : "Test name:").font(.headline)
                    TextField("", text: $testName).textFieldStyle(.roundedBorder)
                }.padding()
                
                // Random picker button
                Button(action: { showRandomPicker = true }) {
                    HStack {
                        Image(systemName: "dice.fill").foregroundColor(.orange)
                        Text(langManager.isRussian ? "🎲 Выбрать случайно" : "🎲 Pick Random")
                            .font(.body).fontWeight(.medium)
                    }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.orange).cornerRadius(10)
                }.padding(.horizontal).padding(.bottom, 8)
                
                // Question list
                Text(langManager.isRussian ? "Выберите вопросы: \(selectedIds.count)" : "Select questions: \(selectedIds.count)").font(.headline).padding(.horizontal).padding(.top, 8)
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(allQuestions) { q in
                            HStack {
                                Text(q.question).font(.body).lineLimit(2).foregroundColor(.primary)
                                Spacer()
                                Image(systemName: selectedIds.contains(q.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedIds.contains(q.id) ? .green : .gray)
                            }.padding(12).background(selectedIds.contains(q.id) ? Color.green.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                                .cornerRadius(10).onTapGesture {
                                    if selectedIds.contains(q.id) { selectedIds.remove(q.id) }
                                    else { selectedIds.insert(q.id) }
                                }
                        }
                    }.padding(.horizontal)
                }
                
                // Save button
                Button(action: saveTest) {
                    Text(langManager.isRussian ? "💾 Сохранить тест" : "💾 Save Test")
                        .font(.title3).fontWeight(.bold).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(testName.isEmpty || selectedIds.isEmpty ? Color.gray : Color.green).cornerRadius(12)
                }.disabled(testName.isEmpty || selectedIds.isEmpty).padding()
            }.navigationTitle(langManager.isRussian ? "Новый тест" : "New Test")
                
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(langManager.isRussian ? "Отмена" : "Cancel") { onDismiss() }
                    }
                }
        }.onAppear { allQuestions = QuestionFileManager.shared.loadQuestions() }
            .frame(minWidth: 700, minHeight: 600)
            .sheet(isPresented: $showRandomPicker) {
                RandomPickerView(totalQuestions: allQuestions.count, selectedCount: $randomCount, onPick: { count in
                    let shuffled = allQuestions.shuffled()
                    selectedIds = Set(shuffled.prefix(count).map { $0.id })
                    showRandomPicker = false
                })
                .frame(minWidth: 400, minHeight: 350)
            }
    }
    
    func saveTest() {
        let test = QuizTest(name: testName, questionIds: Array(selectedIds))
        TestManager.shared.addTest(test)
        onDismiss()
    }
}

// MARK: - Random Picker View
struct RandomPickerView: View {
    let totalQuestions: Int
    @Binding var selectedCount: Int
    let onPick: (Int) -> Void
    @ObservedObject var langManager = LanguageManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                Text("🎲").font(.system(size: 60))
                Text(langManager.isRussian ? "Случайный выбор вопросов" : "Random Question Picker").font(.title2).fontWeight(.bold)
                
                VStack(spacing: 15) {
                    Text(langManager.isRussian ? "Количество вопросов:" : "Number of questions:").font(.headline)
                    Stepper("\(selectedCount)", value: $selectedCount, in: 1...min(totalQuestions, 35))
                        .font(.title2).frame(maxWidth: 200)
                }.padding()
                
                Button(action: { onPick(selectedCount) }) {
                    Text(langManager.isRussian ? "✅ Выбрать" : "✅ Pick").font(.title2).fontWeight(.bold).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.blue).cornerRadius(12)
                }.padding(.horizontal, 40)
                
                Spacer()
            }.navigationTitle(langManager.isRussian ? "Случайный выбор" : "Random Pick")

                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(langManager.isRussian ? "Отмена" : "Cancel") { dismiss() }
                    }
                }
        }.frame(minWidth: 400, minHeight: 350)
    }
}

// MARK: - Main Menu View
struct MainMenuView: View {
    let onStartQuiz: () -> Void
    let onTests: () -> Void
    let onAddQuestion: () -> Void
    let onManageQuestions: () -> Void
    let onSettings: () -> Void

    @State private var totalQuestions = 0
    @ObservedObject var langManager = LanguageManager.shared

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.23, green: 0.49, blue: 0.96), Color(red: 0.55, green: 0.36, blue: 0.64)]), startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with language switcher - fixed at top
                HStack {
                    Spacer()
                    Menu {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Button(action: { langManager.currentLanguage = lang }) {
                                Text(lang.displayName)
                                if langManager.currentLanguage == lang { Image(systemName: "checkmark") }
                            }
                        }
                    } label: {
                        Text(langManager.currentLanguage.displayName)
                            .font(.body).fontWeight(.medium).foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.white.opacity(0.2)).cornerRadius(8)
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 24).padding(.vertical, 12)
                
                // Centered content
                VStack(spacing: 30) {
                    Spacer()
                    
                    Text("📝").font(.system(size: 80))
                    Text(langManager.isRussian ? "Тесты" : "Tests").font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
                    Text("\(langManager.isRussian ? "Вопросов в базе" : "Questions in database"): \(totalQuestions)").font(.title3).foregroundColor(.white.opacity(0.8))

                    VStack(spacing: 15) {
                        Button(action: onStartQuiz) {
                            Text(langManager.isRussian ? "🚀 Быстрый тест (все вопросы)" : "🚀 Quick Quiz (all questions)").font(.title2).fontWeight(.bold).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 18)
                                .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.15, green: 0.40, blue: 0.90), Color(red: 0.45, green: 0.25, blue: 0.70)]), startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        Button(action: onTests) {
                            Text(langManager.isRussian ? "📚 Мои тесты" : "📚 My Tests").font(.title2).fontWeight(.bold).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 18).background(Color.white.opacity(0.15)).cornerRadius(14)
                        }
                        Button(action: onAddQuestion) {
                            Text(langManager.isRussian ? "➕ Добавить вопрос" : "➕ Add Question").font(.title2).fontWeight(.bold).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 18).background(Color.white.opacity(0.15)).cornerRadius(14)
                        }
                        Button(action: onManageQuestions) {
                            Text(langManager.isRussian ? "📋 Управление вопросами" : "📋 Manage Questions").font(.title2).fontWeight(.bold).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 18).background(Color.white.opacity(0.15)).cornerRadius(14)
                        }
                        Button(action: onSettings) {
                            Text(langManager.isRussian ? "⚙️ Настройки" : "⚙️ Settings").font(.title2).fontWeight(.bold).foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 18).background(Color.white.opacity(0.15)).cornerRadius(14)
                        }
                    }.padding(.horizontal, 60)
                    
                    Spacer()
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { totalQuestions = QuestionFileManager.shared.loadQuestions().count }
    }
}

// MARK: - App
@main
struct QuizApp: App {
    @State private var currentScreen: String = "menu"
    @State private var customQuestions: [Question]? = nil

    var body: some Scene {
        WindowGroup {
            Group {
                if currentScreen == "menu" {
                    MainMenuView(
                        onStartQuiz: { customQuestions = nil; currentScreen = "quiz" },
                        onTests: { currentScreen = "tests" },
                        onAddQuestion: { currentScreen = "add" },
                        onManageQuestions: { currentScreen = "manage" },
                        onSettings: { currentScreen = "settings" }
                    )
                } else if currentScreen == "tests" {
                    TestsView(onBack: { currentScreen = "menu" }) { questions in
                        customQuestions = questions
                        currentScreen = "quiz"
                    }
                } else if currentScreen == "quiz" {
                    QuizView(questions: customQuestions, onBack: { currentScreen = "menu" })
                } else if currentScreen == "add" {
                    AddQuestionView(onBack: { currentScreen = "menu" })
                } else if currentScreen == "manage" {
                    ManageQuestionsView(onBack: { currentScreen = "menu" })
                } else if currentScreen == "settings" {
                    SettingsView(onBack: { currentScreen = "menu" })
                }
            }
            .frame(minWidth: 900, minHeight: 750)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 750)
    }
}
