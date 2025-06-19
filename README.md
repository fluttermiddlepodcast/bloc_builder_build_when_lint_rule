# Пишем кастомные правила линтера для Dart и Flutter-проектов

[Стандартный набор правил Дартового линтера](https://dart.dev/tools/linter-rules) содержит много готовых проверок кода,
которые помогают нам выявлять потенциальные ошибки и проблемы в проекте.

Однако, иногда приходится писать собственные правила для линтера. Поводом может стать как отсутствие готового решения в
наборе правил языка, так и желание покрыть важные части кода проверками, которые лучше доверить независимому
интсрументу.

Dart имеет свой фреймворк для создания подобных решений, и называется
он [analyzer_plugin](https://pub.dev/packages/analyzer_plugin). К сожалению, сейчас он не доступен для общего
пользования, и в целом разработка на нем требует больше подготовительных моментов, нежели другие решения.

Мы будем использовать [custom_lint](https://pub.dev/packages/custom_lint). Это стороннее решение для создания
собственных правил линтера. Плагин поддерживается сообществом, содержит рабочие примеры кода, а так же дает возможность
запускать свои правила отдельно из CLI.

## Что будем проверять?

Возьмем как пример реальный кейс, который может иногда встречаться на Flutter-проектах. Будем разбирать его в
рамках [bloc_example](https://github.com/fluttermiddlepodcast/bloc_example), небольшого репозитория, где мы
изучаем [flutter_bloc](https://pub.dev/packages/flutter_bloc).

*Цель: нужно правило для проверки всех виджетов `BlocBuilder` на наличие параметра `buildWhen`. Это аргумент, который
позволяет определить, нужно ли обновлять UI при изменении состояния, тем самым минимизируя лишние перерисовки во
время ненужных обновлений. Если вы не работали с `flutter_bloc`, то начать
можно [отсюда](https://github.com/fluttermiddlepodcast/bloc_example). В репозитории есть ссылки на видео-материалы и
выпуски подкаста, а так же [обзор `BlocBuilder`](https://youtu.be/98iF13KKdss).*

**Опираясь на код, вот так неправильно:**

```dart
@override
Widget build(BuildContext context) {
  return BlocBuilder<AuthBloc, AuthState>(
    builder: (context, state) {
      return state.isAuthenticated ? HomePage() : LoginPage();
    },
  );
}
```

**А вот так правильно:**

```dart
@override
Widget build(BuildContext context) {
  return BlocBuilder<AuthBloc, AuthState>(
    buildWhen: (previous, current) {
      return previous.isAuthenticated != current.isAuthenticated;
    },
    builder: (context, state) {
      return state.isAuthenticated ? HomePage() : LoginPage();
    },
  );
}
```

Если параметр `buildWhen` не указан, то мы увидим ошибку в IDE, либо же во время прогона CI.

**IDE покажет такой вывод:**

![Error in IDE](./media/error_ide.png)

**CI или консоль выдаст следующее:**

![Error in CI](./media/error_ci.png)

## Разбор кода

## Запуск

### Локально

После создания правила, нужно добавить его в ваш проект. Поскольку мы зависим от `custom_lint`, его так же нужно
импортировать в `dev_dependencies`.

**Из Git-репозитория добавление будет таким:**

```yaml
dev_dependencies:
  custom_lint: ^0.1.0
  bloc_builder_build_when_rule:
    git:
      url: https://github.com/fluttermiddlepodcast/bloc_builder_build_when_lint_rule.git
      ref: master
```

**Если плагин расположен локально, то можно просто указать относительный путь от проекта до правила:**

```yaml
dev_dependencies:
  custom_lint: ^0.1.0
  bloc_builder_build_when_rule:
    path: ../bloc_builder_build_when_lint_rule
```

**Далее запускаем `dart pub get` для загрузки зависимостей и подключения их в проект:**

```shell
$ dart pub get
```

После анализа проекта плагин будет доступен в проекте. Если у вас есть какие-то виджеты типа `BlocBuilder` без
указанного `buildWhen`, IDE начнет подсвечивать их инициализацию с
ошибкой. [Ветка bloc_example с нашим правилом](https://github.com/fluttermiddlepodcast/bloc_example/tree/custom_lint)
содержит невалидный по меркам правила код, можете выгрузить и убедиться в работоспособности плагина.

**Для запуска всех проверок `custom_lint`, достаточно выполнить из терминала:**

```shell
$ dart pub run custom_lint
```

### CI

Конфигурацию для GitHub Actions можно
найти [тут](https://github.com/fluttermiddlepodcast/bloc_example/blob/custom_lint/.github/workflows/flutter.yaml). Если
вам интересно, что там дополнительно навешано для оптимизации запуска CI, и как еще можно оптимизировать ваши проверки,
рекомендую посмотреть [отдельное видео](https://youtu.be/NxY6mGaIzKY) по этой теме.

**Сама часть с `custom_lint` будет выглядить следующим образом:**

```yaml
custom_lint:
  runs-on: ubuntu-latest
  needs: changes
  if: needs.changes.outputs.any_changed == 'true'
  steps:
    - uses: actions/checkout@v4
    - uses: kuhnroyal/flutter-fvm-config-action@v2
      id: fvm-config-action
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: ${{ steps.fvm-config-action.outputs.FLUTTER_VERSION }}
        channel: ${{ steps.fvm-config-action.outputs.FLUTTER_CHANNEL }}
    - name: Get dependencies
      run: flutter pub get
    - name: Analyze code
      run: flutter pub run custom_lint ${{ needs.changes.outputs.all_changed_files }}
```

Упавший билд CI можно посмотреть [в этом пулл реквесте](https://github.com/fluttermiddlepodcast/bloc_example/pull/12).

## Выводы

Пример из проекта - лишь капля в море возможностей реализации проверок вашего кода. Писать собственные правила не так
трудно, нужно лишь время на разбор концепций и написание инструментов.

Импакт от таких решений на больших проектах можно оценить в уменьшении времени проверки кода коллег, следованию
регламентам компании, и в целом меньшим количеством споров и глупых потенциальных ошибок.
