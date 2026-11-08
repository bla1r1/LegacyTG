# LegacyTG

Читать на других языках: [English](README.md)

Клиент Telegram для iOS 6.0–12.5.7 на старом железе: интерфейс на
Objective-C и UIKit поверх [TDLib](https://github.com/tdlib/td). Сборка armv7
загружает TDLib во время работы как `libtdjson.dylib`, сборка arm64 линкует её
внутрь.

Тексты берутся из официальных языковых пакетов Telegram, которые скачивает
TDLib; если перевода нет, остаётся английский. Цвета берутся из официальных
файлов тем Telegram (`.tgios-theme`, `.attheme`), светлых и тёмных; Night Blue
встроена.

## Поддерживаемые устройства

Функции включаются по классу устройства, а не по версии iOS. Настройки > Это
устройство объясняют каждую недоступную кнопку.

| Класс | Устройства |
|---|---|
| Vintage | iPhone 3GS/4, iPod touch 4: 256–512 МБ, armv7, iOS ≤ 7 |
| Legacy | iPhone 4S/5/5c, iPod touch 5: armv7, iOS ≤ 10 |
| Modern | iPhone 5s/6/6 Plus, iPod touch 6: первые 64-битные, iOS ≤ 12.5 |
| Full | iPhone 6s и новее: от 2 ГБ |

На iPad приложение ставится и работает в портретной раскладке iPhone.

| Пакет | Размер (1.1) | Для чего |
|---|---|---|
| `LegacyTG-armv7.ipa` | 22 МБ | iOS 6.0+, 32 бита |
| `LegacyTG-arm64.ipa` | 24 МБ | iOS 7.0–12.5.7, 64 бита |
| `LegacyTG.ipa` | 37 МБ | оба среза |

## Настройка

Зарегистрируйте приложение на https://my.telegram.org → API development tools, затем:

```bash
cp vendor/include/tg_config.h.example vendor/include/tg_config.h
```

и заполните `TG_API_ID` и `TG_API_HASH`. Файл в `.gitignore`.

## Сборка

Нужен Xcode с iOS SDK и

```bash
brew install cmake gperf ccache ldid llvm
```

```bash
git clone --recursive https://github.com/bla1r1/iTgLegacy.git
cd iTgLegacy
scripts/build_all.sh
```

`build_all.sh` проходит от пустого `build/` до трёх релизных IPA в
`build/ipa/` с файлом `SHA256SUMS`: SDK, OpenSSL, libvpx, FFmpeg, TDLib дважды,
проверка релиза, затем `make ipa`. Сборка с нуля занимает 30–60 мин; шаг
пропускается, если его результат уже есть. `scripts/build_all.sh --deps`
останавливается после зависимостей.

Готовые `vendor/libs/libcrypto-universal.a`, `libssl-universal.a`,
`WebP.framework` и `third_party/opus/lib/libopus.a` в `.gitignore`, их нужно
взять из прежнего клона.

### Когда зависимости собраны

| Команда | Что делает |
|---|---|
| `make -j8 ipa` | Все три пакета |
| `make -j8 ipa-armv7` | 32-битный IPA |
| `make -j8 ipa-arm64` | 64-битный IPA |
| `make -j8 DEV=1` | Dev-сборка: меню разработчика, тестовые чаты, бенч, URL автоматизации; в релиз не попадает |
| `make clean` | Удаляет `build/armv7`, `build/arm64` и `build/ipa` вместе с зависимостями под архитектуры; после него снова `build_all.sh` |
| `make -j8 -f tests/Makefile test` | Тесты на хосте |
| `scripts/devrun.sh` | Сборка, установка, запуск, лог и скриншот на устройстве по SSH |
| `scripts/check_release.sh` | Падает, если что-то из-под `TG_DEV` попало в релиз |

## Структура репозитория

```
iTgLegacy/
├── Makefile
├── src/
│   ├── App/          # main, AppDelegate, URL-роутинг, dev-бенч
│   ├── Features/     # экраны по зонам
│   │   ├── Auth/  BotsPayments/  Business/  Calls/  Channels/
│   │   ├── Chat/         # Actions/ Composer/ Core/ Rendering/ Search/ Selection/ Views/
│   │   ├── ChatList/  Contacts/  Groups/  Media/  Profile/
│   │   ├── Settings/  Stories/
│   │   └── Dev/          # меню разработчика и стенды, только TG_DEV
│   ├── Core/
│   │   ├── Client/       # TGClient, мост к TDLib: Account/ Audit/ Chats/ Features/ Messages/ Stories/
│   │   ├── Model/        # разбор сообщений, карточки, текст
│   │   ├── Stores/       # кэши, опции, стикеры, медиа, кастомные эмодзи
│   │   ├── Style/        # метрики TGStyle, цвета TGTheme, файлы тем, отрисовка текста
│   │   ├── Platform/     # классы устройств, capabilities, perf, код-пароль
│   │   └── Support/      # JSON, пакеты обновлений, локализация, QR, даты
│   ├── UI/           # общие Controllers/ Controls/ Format/ Overlays/
│   ├── Views/Icons/  # процедурные иконки и SVG-пути
│   ├── Media/        # декодеры WebP и WebM-стикеров
│   ├── Audio/        # голосовые, музыкальный плеер
│   ├── CallEngine/   # tgcalls: Crypto/ Media/ Network/ Signaling/
│   └── Compat/       # dyld TLV и шимы iOS 6/7
├── resources/        # Info.plist, картинки, шрифты, звуки, встроенные темы
├── third_party/      # libtgvoip, libvpx, opus, ogg, yyjson, …
├── tdlib/td/         # TDLib (git submodule)
├── vendor/           # include/ (tg_config.h), libs/ (готовые, в .gitignore)
├── tools/            # machofix и утилиты для устройства
├── scripts/          # сборка, устройство, линтеры, i18n
├── tests/            # тесты на хосте
└── docs/             # статус по зонам, роадмап, дизайн-спека
```

## Документация

Всё перечислено в [docs/README.md](docs/README.md). Что работает —
[docs/status/README.md](docs/status/README.md), что дальше —
[docs/ROADMAP.md](docs/ROADMAP.md).

## Автор и лицензия

- **[bla1r1](https://github.com/bla1r1)** — автор и мейнтейнер
- **GPLv3** — см. [LICENSE](LICENSE)

Иконки из [Material Design Icons](https://pictogrammers.com/library/mdi/) (Apache 2.0) и [Font Awesome Free](https://fontawesome.com) 6.5.1 (CC BY 4.0), хранятся как SVG-пути в `src/Views/Icons/TGIconPaths.m`. Какая иконка из какого набора — в `scripts/icon_picks.txt`; `scripts/gen_icon_paths.py <папка @mdi/js> <папка @fortawesome/fontawesome-free>` пересобирает файл.

Проект начинался с прототипа [@igkuzm](https://github.com/igkuzm) и был переписан с нуля: TDLib вместо `libtg`, новая архитектура UIKit, медиапайплайн, E2EE-звонки.

> Программа предназначена для сохранения старого оборудования и в образовательных целях. Используйте на свой страх и риск.
