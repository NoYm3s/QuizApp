# 📝 QuizApp

Нативное macOS-приложение для подготовки к тестам и контрольным работам.

![Logo](logo.png)

## 🇷🇺 Русский

### Описание
QuizApp — это приложение для macOS, которое помогает готовиться к тестам и контрольным работам. Включает 35 вопросов по теме "Изобретения и открытия" с возможностью добавления своих вопросов.

### ✨ Возможности

- **🚀 Быстрый тест** — прохождение теста из всех 35 вопросов в случайном порядке
- **📚 Мои тесты** — создание собственных наборов вопросов
  - Ручной выбор вопросов
  - 🎲 Случайный выбор определённого количества вопросов
- **➕ Добавление вопросов** — создание своих вопросов с правильными и неправильными ответами
- **🤖 ИИ-генерация** — автоматическая генерация неправильных ответов с помощью ИИ (Qwen 2.5)
- **📋 Управление вопросами** — просмотр, удаление и сброс вопросов
- **🌐 Два языка** — русский и английский интерфейс
- **📖 Переводы** — показ перевода вопроса и ответа после неправильного ответа
- **⚙️ Настройки** — управление переводами, API ключом ИИ и языком

### 📸 Скриншоты (Русский)

| Главное меню | Тест | Неправильный ответ |
|---|---|---|
| ![Главное меню](screenshots/ru/01_main.png) | ![Тест](screenshots/ru/02_quiz.png) | ![Неправильный ответ](screenshots/ru/03_wrong.png) |

| Результаты | Добавить вопрос | Управление |
|---|---|---|
| ![Результаты](screenshots/ru/04_results.png) | ![Добавить](screenshots/ru/05_add.png) | ![Управление](screenshots/ru/06_manage.png) |

| Настройки |
|---|
| ![Настройки](screenshots/ru/07_settings.png) |

### 📸 Скриншоты (English)

| Main Menu | Quiz | Wrong Answer |
|---|---|---|
| ![Main Menu](screenshots/en/01_main.png) | ![Quiz](screenshots/en/02_quiz.png) | ![Wrong Answer](screenshots/en/03_wrong.png) |

| Results | Add Question | Manage |
|---|---|---|
| ![Results](screenshots/en/04_results.png) | ![Add](screenshots/en/05_add.png) | ![Manage](screenshots/en/06_manage.png) |

| Settings | My Tests | Create Test |
|---|---|---|
| ![Settings](screenshots/en/07_settings.png) | ![Tests](screenshots/en/08_tests.png) | ![Create](screenshots/en/09_create_test.png) |

### 🛠 Установка на macOS

#### Способ 1: Готовое приложение
1. Скачайте `QuizApp.app` из раздела [Releases](https://github.com/noym3s/QuizApp/releases)
2. Переместите в папку `Программы` (Applications)
3. Откройте приложение двойным кликом

#### Способ 2: Сборка из исходного кода
```bash
# Требуется Xcode Command Line Tools
xcode-select --install

# Клонирование репозитория
git clone https://github.com/noym3s/QuizApp.git
cd QuizApp/macOS

# Компиляция
swiftc -parse-as-library -o QuizApp_Binary main.swift -framework SwiftUI -framework AppKit

# Создание .app пакета
mkdir -p QuizApp.app/Contents/MacOS
mkdir -p QuizApp.app/Contents/Resources
cp QuizApp_Binary QuizApp.app/Contents/MacOS/QuizApp

# Подписание
codesign --force --deep --sign - QuizApp.app

# Запуск
open QuizApp.app
```

### 🤖 Настройка ИИ
Для генерации неправильных ответов с помощью ИИ:
1. Зарегистрируйтесь на [openrouter.ai](https://openrouter.ai)
2. Создайте API ключ в разделе Keys
3. В приложении: Настройки → Введите API ключ → Сохранить

### 📁 Структура проекта
```
QuizApp/
├── macOS/
│   └── main.swift          # Исходный код macOS приложения
├── Windows/
│   └── quiz.html           # HTML версия для Windows
├── screenshots/
│   ├── ru/                 # Скриншоты на русском
│   └── en/                 # Скриншоты на английском
├── logo.png                # Логотип приложения
└── README.md               # Этот файл
```

---

## 🇬🇧 English

### Description
QuizApp is a native macOS application that helps you prepare for tests and quizzes. It includes 35 questions on "Inventions & Discoveries" with the ability to add your own questions.

### ✨ Features

- **🚀 Quick Quiz** — take a test with all 35 questions in random order
- **📚 My Tests** — create custom question sets
  - Manual question selection
  - 🎲 Random selection of a specific number of questions
- **➕ Add Questions** — create your own questions with correct and wrong answers
- **🤖 AI Generation** — automatic wrong answer generation using AI (Qwen 2.5)
- **📋 Manage Questions** — view, delete and reset questions
- **🌐 Two Languages** — Russian and English interface
- **📖 Translations** — show question and answer translations after wrong answers
- **⚙️ Settings** — manage translations, AI API key and language

### 🛠 Installation on macOS

#### Method 1: Pre-built App
1. Download `QuizApp.app` from [Releases](https://github.com/noym3s/QuizApp/releases)
2. Move to `Applications` folder
3. Open the app by double-clicking

#### Method 2: Build from Source
```bash
# Requires Xcode Command Line Tools
xcode-select --install

# Clone repository
git clone https://github.com/noym3s/QuizApp.git
cd QuizApp/macOS

# Compile
swiftc -parse-as-library -o QuizApp_Binary main.swift -framework SwiftUI -framework AppKit

# Create .app bundle
mkdir -p QuizApp.app/Contents/MacOS
mkdir -p QuizApp.app/Contents/Resources
cp QuizApp_Binary QuizApp.app/Contents/MacOS/QuizApp

# Sign
codesign --force --deep --sign - QuizApp.app

# Run
open QuizApp.app
```

### 🤖 AI Setup
To generate wrong answers using AI:
1. Register at [openrouter.ai](https://openrouter.ai)
2. Create an API key in the Keys section
3. In the app: Settings → Enter API key → Save

### 📁 Project Structure
```
QuizApp/
├── macOS/
│   └── main.swift          # macOS app source code
├── Windows/
│   └── quiz.html           # HTML version for Windows
├── screenshots/
│   ├── ru/                 # Russian screenshots
│   └── en/                 # English screenshots
├── logo.png                # App logo
└── README.md               # This file
```

---

## 🪟 Windows Version

Для Windows доступна HTML-версия приложения. Откройте `Windows/quiz.html` в любом браузере.

For Windows, an HTML version is available. Open `Windows/quiz.html` in any browser.

---

## 📄 License

MIT License
