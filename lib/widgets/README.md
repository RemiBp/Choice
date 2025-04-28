# CustomExpansionPanel

A customizable Flutter widget that provides an expansion panel functionality with more styling options than the standard material ExpansionPanel.

## Features

- Full control over appearance including header and content colors, text styles, and border radius
- Custom expand/collapse icons
- Simple API similar to ExpansionTile but with more customization
- Optional animation duration control
- CustomExpansionPanelList for displaying multiple panels

## Usage

### Basic Usage

```dart
CustomExpansionPanel(
  title: 'Expansion Panel Title',
  content: Text('This is the content of the expansion panel'),
  initiallyExpanded: false,
  onExpansionChanged: (isExpanded) {
    // Handle expansion state change
  },
)
```

### Styled Example

```dart
CustomExpansionPanel(
  title: 'Styled Expansion Panel',
  headerColor: Colors.blue.shade100,
  contentBackgroundColor: Colors.blue.shade50,
  headerTextStyle: TextStyle(
    color: Colors.blue.shade800,
    fontWeight: FontWeight.bold,
  ),
  borderRadius: 8.0,
  content: Text('Custom styled expansion panel content'),
  initiallyExpanded: false,
  onExpansionChanged: (isExpanded) {
    // Handle expansion state change
  },
)
```

### Custom Icons

```dart
CustomExpansionPanel(
  title: 'Panel with Custom Icons',
  content: Text('This panel uses custom icons'),
  icon: Icon(Icons.add_circle_outline),
  expandedIcon: Icon(Icons.remove_circle_outline),
  initiallyExpanded: false,
  onExpansionChanged: (isExpanded) {
    // Handle expansion state change
  },
)
```

### Multiple Panels with CustomExpansionPanelList

```dart
CustomExpansionPanelList(
  children: [
    CustomExpansionPanel(
      title: 'Panel 1',
      content: Text('Content for panel 1'),
      initiallyExpanded: false,
      onExpansionChanged: (isExpanded) {
        // Handle panel 1 expansion
      },
    ),
    CustomExpansionPanel(
      title: 'Panel 2',
      content: Text('Content for panel 2'),
      initiallyExpanded: false,
      onExpansionChanged: (isExpanded) {
        // Handle panel 2 expansion
      },
    ),
  ],
)
```

## Properties

### CustomExpansionPanel

| Property | Type | Description |
|----------|------|-------------|
| `title` | `String` | The title displayed in the header of the expansion panel |
| `content` | `Widget` | The widget displayed when the panel is expanded |
| `initiallyExpanded` | `bool` | Whether the panel is initially expanded |
| `onExpansionChanged` | `ValueChanged<bool>?` | Callback when expansion state changes |
| `headerColor` | `Color?` | Background color of the header |
| `contentBackgroundColor` | `Color?` | Background color of the content section |
| `headerTextStyle` | `TextStyle?` | Text style for the header title |
| `borderRadius` | `double?` | Border radius of the panel corners |
| `padding` | `EdgeInsets?` | Padding inside the panel header |
| `icon` | `Widget?` | Custom icon for collapsed state |
| `expandedIcon` | `Widget?` | Custom icon for expanded state |
| `animationDuration` | `Duration?` | Duration of expand/collapse animation |

### CustomExpansionPanelList

| Property | Type | Description |
|----------|------|-------------|
| `children` | `List<CustomExpansionPanel>` | List of expansion panels to display |
| `dividerColor` | `Color?` | Color of dividers between panels |
| `dividerThickness` | `double?` | Thickness of dividers between panels |
| `elevation` | `double?` | Elevation of the panel list |

## Example

See `examples/expansion_panel_examples.dart` for more detailed examples. 