# Laboratory note templates

Chronicle 0.24.4 adds six opt-in templates to the existing new-note sheet. They
create ordinary portable Markdown notes with the same front matter already used
by Chronicle. No existing note is rewritten and no database migration is
required.

## Templates

- **Лабораторный день** records daily goals, sample state, chronological work,
  observations, deviations, generated files and the next action.
- **Эксперимент** separates the research question, hypothesis, materials,
  controlled parameters, protocol, observations, results and interpretation.
- **Паспорт образца** keeps stable sample identity, composition, preparation,
  history, quality control, storage and links to experiments.
- **Экспрессия и очистка** covers construct and host details, induction, lysis,
  chromatography, tag cleavage, analytical checks, yield and final storage.
- **ЯМР-эксперимент** records the sample, spectrometer, probe, pulse sequence,
  acquisition parameters, setup quality, processing and produced files.
- **Буфер или раствор** provides a composition table, preparation steps,
  measured pH, filtration, labeling and storage fields.

## Data behavior

Template IDs and note types are fixed strings used only when a new note is
created. Default tags and properties are copied into that new note and then
behave like ordinary editable metadata. Existing notes, Vault paths,
attachments, synchronization records and user-selected themes are untouched.
