---
name: pdfcn
description: Add PDF components (text, tables, invoices, reports) to a React/shadcn project with pdfcn. Use when asked to generate PDFs, invoices, or reports in a project using shadcn/ui and Tailwind.
---

# pdfcn

Copy-paste PDF components for React via shadcn registry. Docs index: https://pdfcn.dev/llms.txt (read first). Per-page markdown: `https://www.pdfcn.dev/docs/components/takumi/<name>.md`.

## Renderer

- Default: Takumi, `@pdfcn/takumi/*`.
- Forme (`@pdfcn/forme/*`) only if project already uses `@formepdf/react` or user asks.

## Install

```bash
npx shadcn@latest add @pdfcn/takumi/text
```

- Full documents: install a block, e.g. `@pdfcn/takumi/invoice-minimal`. Other blocks: invoice-*, report-*, event-ticket, shipping-label, work-order, etc. Do not build from scratch.
- Themes: https://www.pdfcn.dev/docs/themes.md
- Preserve existing Tailwind and shadcn/ui setup.
- Do not hand-edit registry components unless the command fails. On failure, inspect `https://pdfcn.dev/r/takumi/text.json` and install listed dependencies.

## Basic example

```tsx
import { Document, Page } from "@/components/pdf/pdf-primitives";
import { PdfcnThemeProvider } from "@/components/pdf/theme-provider";
import { Text } from "@/components/pdf/text";

export const Example = () => (
  <Document>
    <Page>
      <PdfcnThemeProvider>
        <Text>Hello pdfcn</Text>
      </PdfcnThemeProvider>
    </Page>
  </Document>
);
```

Check component docs for exact props and where the provider belongs.
