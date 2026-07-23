# Local intelligence and document export

Chronicle 0.32 builds a separate JSON index per project in the application support directory. The index contains normalized text features and can be deleted or rebuilt without changing the Vault.

The first implementation is intentionally transparent: TF-IDF similarity, extractive answers, shared-term links, entity candidates, numerical/negation contradiction heuristics, and chronological extractive summaries. Every answer names its source notes. Suggestions are never applied automatically.

Publication workspaces can additionally export assembled Markdown as DOCX or PDF. DOCX is an editable Open XML document; PDF is generated locally with fixed page layout.
