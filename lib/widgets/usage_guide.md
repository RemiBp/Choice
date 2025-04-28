# CustomExpansionPanel Usage Guide

The `CustomExpansionPanel` is a flexible and customizable widget that provides an expandable panel with a header and content section. It can be used for FAQs, settings panels, detail views, and more.

## Basic Usage

```dart
CustomExpansionPanel(
  title: 'Panel Title',
  content: Text('Panel content goes here'),
)
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String` | The title to display in the header |
| `content` | `Widget` | The content to display when expanded |
| `initiallyExpanded` | `bool` | Whether the panel is initially expanded |
| `headerColor` | `Color?` | The background color of the header |
| `contentBackgroundColor` | `Color?` | The background color of the content |
| `headerTextStyle` | `TextStyle?` | The text style for the header title |
| `borderRadius` | `double?` | The border radius of the panel |
| `padding` | `EdgeInsetsGeometry?` | The padding inside the panel |
| `icon` | `Widget?` | The icon to show when collapsed |
| `expandedIcon` | `Widget?` | The icon to show when expanded |
| `onExpansionChanged` | `ValueChanged<bool>?` | Callback when expansion state changes |

## Advanced Examples

### Styled Panel

```dart
CustomExpansionPanel(
  title: 'Settings',
  headerColor: Colors.blue,
  contentBackgroundColor: Colors.grey[50],
  headerTextStyle: TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
  ),
  borderRadius: 8.0,
  content: YourSettingsContent(),
)
```

### Custom Icons

```dart
CustomExpansionPanel(
  title: 'More Details',
  icon: Icon(Icons.add_circle_outline),
  expandedIcon: Icon(Icons.remove_circle_outline),
  content: YourDetailContent(),
)
```

### With Expansion Change Callback

```dart
CustomExpansionPanel(
  title: 'Section Title',
  content: SectionContent(),
  onExpansionChanged: (isExpanded) {
    // Track analytics or perform actions when expanded/collapsed
    print('Panel is now ${isExpanded ? 'expanded' : 'collapsed'}');
  },
)
```

## Using CustomExpansionPanelList

The `CustomExpansionPanelList` allows you to manage a list of expansion panels together:

```dart
CustomExpansionPanelList(
  children: [
    CustomExpansionPanel(
      title: 'Panel 1',
      content: Panel1Content(),
    ),
    CustomExpansionPanel(
      title: 'Panel 2',
      content: Panel2Content(),
    ),
    CustomExpansionPanel(
      title: 'Panel 3',
      content: Panel3Content(),
    ),
  ],
)
```

## Implementation Tips

1. **Dynamic Content**: You can update the content widget based on state changes
2. **Animations**: The panel includes built-in animations for smooth expansion/collapse
3. **Responsive Design**: The panel adjusts to available width
4. **Nesting**: You can nest panels within other panels for hierarchical content
5. **Accessibility**: The panel is keyboard accessible and works with screen readers 