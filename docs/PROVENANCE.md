# Происхождение и лицензия

`runtime/atv16-controller-hotplug` адаптирован из `extras/scripts/waydroid-controller-hotplug` проекта [pjohno/steamos-waydroid-bundle](https://github.com/pjohno/steamos-waydroid-bundle/tree/8f5cc2a4f55010dc480f153350a7547b501fd49f), ревизия `8f5cc2a4f55010dc480f153350a7547b501fd49f`, GPL v3. Историю исходной основы Ryan Rudolf и последующих изменений см. в [UPSTREAM.md](https://github.com/pjohno/steamos-waydroid-bundle/blob/8f5cc2a4f55010dc480f153350a7547b501fd49f/UPSTREAM.md).

Изменения 27.09.2026: отдельный профиль ATV16 и runtime directory, фиксированный XDG_DATA_HOME, передача Google virtual-remote наряду со Steam Input, проверки имени/ID при повторном использовании event number. GPL сохраняется. Текст GPL v3 приложен в LICENSE.

Остальные launcher/установочные скрипты, mDNS announcer, LAN-proxy orchestration и правило udev подготовлены для этой рабочей конфигурации в ходе настройки Deck. Код комплекта — GPL-3.0-or-later. Никакой аффилиации с Valve, Google, Waydroid или авторами upstream не заявляется.

Образы Android и бинарные host bundles не входят в ZIP. Их загружают только с источников авторов. Закреплённые SHA-256 взяты из публичных OTA-манифестов WayDroid-ATV для релиза 20260403; это проверка целостности относительно источника, не независимая гарантия безопасности стороннего Android.

`archive/` содержит сохранённые материалы прежних попыток и upstream-снимки только для локального аудита. `local/` содержит личное SSH-подключение. Оба каталога исключены из публикуемого комплекта.
