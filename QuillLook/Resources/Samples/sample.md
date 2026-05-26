# QuillLook Sample

QuillLook previews **Markdown** directly in Finder with polished local rendering.

- [x] Task lists
- [ ] Local images
- Tables
- Code highlighting
- Mermaid diagrams
- KaTeX math like $E = mc^2$

## Code

```swift
struct Preview {
    let title: String
}
```

## Table

| Feature | Status |
| --- | --- |
| Quick Look | Built in |
| Mermaid | Bundled |
| KaTeX | Bundled |

## Mermaid

```mermaid
flowchart LR
  A[Finder] --> B[Quick Look]
  B --> C[QuillLook]
  C --> D[Rendered Preview]
```

## Math

$$
\int_0^1 x^2 dx = \frac{1}{3}
$$

> Links open externally, while local file navigation stays blocked inside the preview.

