#!/usr/bin/env python3
"""Builds assets/i18n/strings.csv — the game's translation table.

    python3 tools/make_translations.py

The keys are the English strings themselves. That is deliberate: `tr()` returns
its argument unchanged when there is no entry, so a string nobody has translated
yet still reads correctly in English instead of showing a bare identifier like
UI_MENU_QUIT. Adding a language is adding a column; forgetting a string costs
nothing but the translation.

Names and descriptions of content (furniture, buildings, skills…) are pulled
straight out of the .tres files, so an object added to the game turns up here
automatically and only needs its Russian written in.
"""

from __future__ import annotations

import csv
import glob
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "i18n", "strings.csv")

# Interface strings, grouped the way they appear on screen.
UI = {
    # Main menu and settings
    "My City: Inside": "Мой город: изнутри",
    "Build a street, then look inside it": "Построй улицу и загляни внутрь",
    "Continue": "Продолжить",
    "New town": "Новый город",
    "Settings": "Настройки",
    "Quit": "Выход",
    "Music": "Музыка",
    "Sound effects": "Звуки",
    "Mute everything": "Выключить звук",
    "Close": "Закрыть",
    "Language": "Язык",
    "M mutes, E switches walls, Space pauses":
        "M — звук, E — стены, пробел — пауза",
    "Paused": "Пауза",
    "Save town": "Сохранить город",
    "Main menu": "Главное меню",
    "Town saved": "Город сохранён",
    # View modes
    "VIEW_CUTAWAY": "Вид: сквозь стены",
    "VIEW_OUTSIDE": "Вид: снаружи",
    "VIEW_NO_WALLS": "Вид: без стен",
    "Walls": "Стены",
    # Tools
    "Select": "Выбор",
    "Wall": "Стена",
    "Door": "Дверь",
    "Window": "Окно",
    "Room": "Комната",
    "Furniture": "Мебель",
    "Plot": "Участок",
    "Move in": "Заселить",
    "Delete": "Снести",
    "Pick": "Выбор",
    "Win": "Окно",
    "Item": "Вещь",
    "Move": "Жильцы",
    "Del": "Снос",
    "Rotate (R)": "Повернуть (R)",
    "%d room(s)": "комнат: %d",
    # HUD
    "day": "день",
    "night": "ночь",
    "paused": "пауза",
    "one finger — pan    two fingers — zoom    tap a resident to follow them":
        "один палец — карта, два — зум, тап по жителю — следить за ним",
    "WASD — move    wheel — zoom    E — walls    G — grid    Space — pause    +/− — speed    F3 — debug    M — music":
        "WASD — движение, колесо — зум, E — стены, G — сетка, пробел — пауза, +/− — скорость, F3 — отладка, M — музыка",
    # Resident panel
    "Hunger": "Голод",
    "Energy": "Энергия",
    "Hygiene": "Чистота",
    "Comfort": "Комфорт",
    "Entertainment": "Развлечение",
    "Social": "Общение",
    "Work": "Работа",
    "hunger": "голод",
    "energy": "энергия",
    "hygiene": "чистота",
    "comfort": "комфорт",
    "fun": "развлечение",
    "company": "общение",
    "work": "работа",
    "savings": "накопления",
    "today": "сегодня",
    "Unemployed": "Без работы",
    "friends": "друзья",
    "close friends": "близкие друзья",
    "friendly": "приятели",
    "acquainted": "знакомые",
    "strangers": "незнакомы",
    "cool": "прохладно",
    "hostile": "враждуют",
    # States
    "Idle": "Без дела",
    "Walking": "Идёт",
    "Eating": "Ест",
    "Sleeping": "Спит",
    "Working": "Работает",
    "Relaxing": "Отдыхает",
    "Showering": "Моется",
    "Socializing": "Общается",
    "Going home": "Идёт домой",
    "REASON_WALK": "Гуляет",
    # Object panel
    "In use right now": "Сейчас занято",
    "Nothing to do with it — it is here to look at.":
        "Пользоваться нечем — стоит для вида.",
    "%d min": "%d мин",
    "trains %s": "качает: %s",
    "$%d/day upkeep": "$%d/день содержание",
    "comfort %d": "комфорт %d",
    "fun %d": "развлечение %d",
    # Rooms
    "Undefined": "Без назначения",
    "Living room": "Гостиная",
    "Bedroom": "Спальня",
    "Kitchen": "Кухня",
    "Bathroom": "Ванная",
    "Children room": "Детская",
    "Dining room": "Столовая",
    "Hallway": "Прихожая",
    "Storage": "Кладовая",
    "Garage": "Гараж",
    "(no door)": "(нет двери)",
    # Notices
    "A town: four families, a shop, a cafe, an office, a gym, a library and a park":
        "Городок: четыре семьи, магазин, кафе, офис, спортзал, библиотека и парк",
    "Sound off": "Звук выключен",
    "Anna": "Анна",
    "Boris": "Борис",
    "Clara": "Клара",
    "Daniel": "Даниил",
    "Elena": "Елена",
    "Felix": "Феликс",
    "Greta": "Грета",
    "Hugo": "Гуго",
    "Irina": "Ирина",
    "Jonas": "Йонас",
    "Kira": "Кира",
    "Lena": "Лена",
    "Mark": "Марк",
    "Nina": "Нина",
    "Oscar": "Оскар",
    "Pavel": "Павел",
    "Rita": "Рита",
    "Sofia": "София",
    "Timur": "Тимур",
    "Vera": "Вера",
    "Adler": "Адлер",
    "Beck": "Бек",
    "Cross": "Кросс",
    "Dorn": "Дорн",
    "Egan": "Иган",
    "Fisher": "Фишер",
    "Gould": "Гулд",
    "Hart": "Харт",
    "Ivers": "Иверс",
    "Kane": "Кейн",
    "Lund": "Лунд",
    "Meyer": "Майер",
    "Novak": "Новак",
    "Ortiz": "Ортис",
    "Pike": "Пайк",
    "Quill": "Квилл",
    "Rossi": "Росси",
    "Stein": "Штейн",
    "Toth": "Тот",
    "Vogel": "Фогель",
    "Monday": "Понедельник",
    "Tuesday": "Вторник",
    "Wednesday": "Среда",
    "Thursday": "Четверг",
    "Friday": "Пятница",
    "Saturday": "Суббота",
    "Sunday": "Воскресенье",
    "Mon": "Пн",
    "Tue": "Вт",
    "Wed": "Ср",
    "Thu": "Чт",
    "Fri": "Пт",
    "Sat": "Сб",
    "Sun": "Вс",
    "Floor": "Пол",
    "/day": "/день",
    "The %ss": "%sы",
    "The %s": "%s",

    "%s moved into %s (%d residents)": "%s заселились в %s (жильцов: %d)",
    "on shift": "на смене",
    "no fixed address": "без адреса",
    "no routine": "без распорядка",
    "lv %d": "ур. %d",
    "m²": "м²",
    "reluctantly": "нехотя",
    "favourite": "любимое",
    "Night": "Ночь",
    "Morning": "Утро",
    "Daytime": "День",
    "Lunch": "Обед",
    "Afternoon": "После обеда",
    "Dinner": "Ужин",
    "Evening": "Вечер",
    "night": "ночь",
    "morning": "утро",
    "daytime": "день",
    "lunch": "обед",
    "afternoon": "после обеда",
    "dinner": "ужин",
    "evening": "вечер",
    "Seating": "Сидения",
    "Sleeping": "Кровати",
    "Surface": "Столы",
    "Appliance": "Техника",
    "Plumbing": "Сантехника",
    "Storage": "Хранение",
    "Electronics": "Электроника",
    "Decor": "Декор",
    "Lighting": "Свет",
    "Sound on": "Звук включён",
}

# Content: display names and descriptions out of the .tres files.
CONTENT = {
    # Furniture
    "Single Bed": "Односпальная кровать",
    "Bookshelf": "Книжный шкаф",
    "Chair": "Стул",
    "Coffee Machine": "Кофемашина",
    "Computer": "Компьютер",
    "Desk": "Письменный стол",
    "Bench": "Скамья",
    "Easel": "Мольберт",
    "Fridge": "Холодильник",
    "Guitar": "Гитара",
    "Kitchen Counter": "Кухонная тумба",
    "Floor Lamp": "Торшер",
    "Shower": "Душ",
    "Sofa": "Диван",
    "Stove": "Плита",
    "Dining Table": "Обеденный стол",
    "Treadmill": "Беговая дорожка",
    "Tree": "Дерево",
    "TV": "Телевизор",
    # Interactions
    "Sleep": "Спать",
    "Read": "Читать",
    "Sit": "Сидеть",
    "Coffee": "Кофе",
    "Play": "Играть",
    "Work": "Работать",
    "Chat": "Болтать",
    "Paint": "Рисовать",
    "Get Food": "Взять еду",
    "Play music": "Играть музыку",
    "Perform": "Выступать",
    "Make a sandwich": "Сделать бутерброд",
    "Cook a feast": "Приготовить пир",
    "Shower": "Душ",
    "Relax": "Отдыхать",
    "Cook": "Готовить",
    "Eat": "Есть",
    "Exercise": "Тренироваться",
    "Watch TV": "Смотреть ТВ",
    # Floors
    "Wood": "Паркет",
    "Tile": "Плитка",
    "Carpet": "Ковролин",
    "Road": "Дорога",
    "Pavement": "Тротуар",
    # Buildings
    "Small House": "Дом",
    "Apartment Block": "Многоквартирный дом",
    "Shop": "Магазин",
    "Office": "Офис",
    "Cafe": "Кафе",
    "Gym": "Спортзал",
    "Library": "Библиотека",
    "Park": "Парк",
    # Skills
    "Cooking": "Готовка",
    "Logic": "Логика",
    "Fitness": "Спорт",
    "Music": "Музыка",
    "Painting": "Живопись",
    "Charisma": "Харизма",
    # Jobs, archetypes, schedules
    "Worker": "Рабочий",
    "Office Worker": "Офисный работник",
    "Adult": "Взрослый",
    "Lazy": "Ленивый",
    "Neat": "Аккуратный",
    "Sociable": "Общительный",
    "Ordinary day": "Обычный день",
    # City events
    "Street Festival": "Уличный фестиваль",
    "Heatwave": "Жара",
    "Flu Going Round": "Эпидемия гриппа",
    "Quiet Weekend": "Тихие выходные",
    "City Grant": "Городской грант",
    "Repair Bill": "Счёт за ремонт",
}

DESCRIPTIONS = {
    "A bigger residential plot: room for a large family.":
        "Участок побольше: хватит на большую семью.",
    "A place to sit down.": "Место, чтобы присесть.",
    "A place to work from home. Pays whatever the job pays.":
        "Место для работы из дома. Платят столько же, сколько на работе.",
    "A plot for one household. Build the rooms yourself.":
        "Участок на одну семью. Комнаты строишь сам.",
    "A quick snack, no cooking required.": "Быстрый перекус, готовить не надо.",
    "A working-age resident with no particular quirks.":
        "Взрослый житель без особых причуд.",
    "Better cooks make bigger meals in less time.":
        "Кто лучше готовит, тот делает больше еды и быстрее.",
    "Cannot relax in a dirty flat. Showers first, enjoys life second.":
        "Не может расслабиться в грязной квартире. Сначала душ, потом всё остальное.",
    "Cold, easy to clean. Made for kitchens and bathrooms.":
        "Холодная, легко мыть. Для кухни и ванной.",
    "Comfortable seating for up to three.": "Удобно сидеть втроём.",
    "Commercial plot with desks. Office workers commute here.":
        "Коммерческий участок со столами. Сюда ходят офисные работники.",
    "Commercial plot. Somewhere for shopkeepers to work.":
        "Коммерческий участок. Место работы для продавцов.",
    "Company is more rewarding when you are good at it.":
        "Общение приятнее, когда умеешь общаться.",
    "Cooking takes longer but fills you up properly.":
        "Готовка дольше, зато сытно по-настоящему.",
    "Costs energy and hygiene now, makes energy last longer forever after.":
        "Сейчас тратит силы и чистоту, зато потом энергии хватает надолго.",
    "Decorative for now; it will light the room at night.":
        "Пока просто украшение; ночью будет светить.",
    "Desk job in a commercial building. Fixed hours, steady salary.":
        "Работа за столом в коммерческом здании. Твёрдый график, стабильная зарплата.",
    "Five minutes for a burst of energy. Not a substitute for sleep.":
        "Пять минут ради бодрости. Сон не заменяет.",
    "General labour. Long hours, modest pay, no qualifications required.":
        "Простая работа. Долгие смены, скромная оплата, без требований.",
    "Half the street is sniffling. Energy drains and nobody feels sociable.":
        "Полулицы сопливит. Силы тают, общаться никому не хочется.",
    "Music in the street tonight — nobody wants to be indoors alone.":
        "Вечером на улице музыка — сидеть дома одному никому не хочется.",
    "Needs company. Will cross the flat for someone to talk to.":
        "Нужна компания. Пройдёт через всю квартиру ради разговора.",
    "Nothing much on. A good day to rest and see people.":
        "Дел немного. Хороший день, чтобы отдохнуть и повидаться.",
    "Painting is slow, trains a skill, and finished work sells.":
        "Живопись медленная, качает навык, а готовое продаётся.",
    "Pipes, wiring, the usual. It has to be paid.":
        "Трубы, проводка, обычное дело. Платить придётся.",
    "Playing badly is a chore; playing well is a joy.":
        "Играть плохо — мучение, играть хорошо — радость.",
    "Prep space. A skilled cook can put together a proper dinner here.":
        "Место для готовки. Умелый повар соберёт здесь настоящий ужин.",
    "Reading is slow entertainment that quietly trains logic.":
        "Чтение — медленное развлечение, которое тихо качает логику.",
    "Sleeps at night, eats at the usual hours, relaxes in the evening.":
        "Спит ночью, ест в обычные часы, вечером отдыхает.",
    "Slow to learn, and the results can be sold.":
        "Учится медленно, зато результат можно продать.",
    "Soft and quiet. The most comfortable option for bedrooms.":
        "Мягко и тихо. Самый уютный вариант для спальни.",
    "Somewhere to sit together. Company is worth more with charisma.":
        "Место, чтобы посидеть вместе. С харизмой компания ценнее.",
    "Terrible at first, wonderful later. Skill changes how much it gives.":
        "Сначала ужасно, потом прекрасно. Навык меняет отдачу.",
    "The cheapest entertainment in the house.":
        "Самое дешёвое развлечение в доме.",
    "The council paid out. Money in the budget, briefly.":
        "Совет выплатил грант. Деньги в бюджете — ненадолго.",
    "Thinking work. Employers pay for it.":
        "Умственная работа. За неё платят.",
    "Tires quickly, walks slowly, and would rather sit than cook.":
        "Быстро устаёт, ходит медленно и охотнее посидит, чем приготовит.",
    "Too hot to think. Everyone is washing twice a day.":
        "Слишком жарко, чтобы думать. Все моются дважды в день.",
    "Training makes energy last longer through the day.":
        "Тренировки растягивают запас сил на день.",
    "Twenty minutes, and hygiene is solved.":
        "Двадцать минут — и вопрос чистоты закрыт.",
    "Warm parquet. Cheap and suits most living spaces.":
        "Тёплый паркет. Дёшево и подходит почти везде.",
    "Where meals are eaten, together if possible.":
        "Здесь едят, по возможности вместе.",
    "Work during the day, entertainment in the evening — the AI picks by itself.":
        "Днём работа, вечером развлечения — ИИ выбирает сам.",
    "Sleep restores energy. One person at a time.":
        "Сон восстанавливает энергию. По одному человеку.",
    "A tree. Nobody can do anything with it, which is the point: a street with trees looks lived in.":
        "Дерево. С ним ничего нельзя сделать — в этом и смысл: улица с деревьями выглядит обжитой.",
    "Asphalt. Cars drive on it, people walk across it.":
        "Асфальт. По нему ездят машины и переходят люди.",
    "Slabs for walking on, along the road and through the park.":
        "Плитка для пешеходов — вдоль дороги и через парк.",
}


def collected_content() -> dict[str, str]:
    """Every display name and description in the content files, so nothing is
    missed and nothing has to be listed twice."""
    found: dict[str, str] = {}
    pattern = re.compile(r'^(display_name|description) = "(.*)"$')
    for path in sorted(glob.glob(os.path.join(ROOT, "resources", "**", "*.tres"), recursive=True)):
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                match = pattern.match(line.strip())
                if not match or not match.group(2):
                    continue
                english = match.group(2)
                found[english] = CONTENT.get(english, DESCRIPTIONS.get(english, ""))
    return found


def main() -> None:
    rows = dict(UI)
    for english, russian in collected_content().items():
        rows.setdefault(english, russian)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["keys", "en", "ru"])
        for english in sorted(rows):
            # An empty Russian cell would translate to an empty label, so an
            # untranslated string keeps its English text in both columns.
            writer.writerow([english, english, rows[english] or english])
    missing = [key for key, value in rows.items() if not value]
    print("wrote %d strings to %s" % (len(rows), OUT))
    if missing:
        print("still English:", ", ".join(sorted(missing)[:12]))


if __name__ == "__main__":
    main()
