# Contributing to IELTS Free

Thanks for wanting to help! IELTS Free is an offline-first, open-source IELTS
learning app. Contributions of all sizes are welcome.

By participating you agree to follow our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Ways to contribute

### Code contributions

Bug fixes, new features, refactors, performance work and tests are all welcome.

1. **Fork** the repository and create a branch:
   `git checkout -b feat/short-description`.
2. Follow the existing architecture and layering
   (see [`docs/ARCHITECTURE-v0.1.md`](docs/ARCHITECTURE-v0.1.md)).
3. Keep the code clean and typed:
   - Dart **3.4+** only, no new dependencies without discussion.
   - **Do not** add code generation (`build_runner`, `drift`, `json_serializable`).
     Route B uses hand-written SQL and DAOs on purpose.
   - **Do not** add any runtime-networking package. Offline is a hard constraint.
   - Use `AppColors` / `ColorScheme` for colors and `AppSpacing` for spacing —
     never hard-code values in a page.
   - Never use `print`; use the local logger.
4. Run the checks locally:
   ```bash
   flutter pub get
   flutter analyze
   flutter test
   ```
   All three must pass. (There is no codegen step.)
5. Open a pull request and fill in the PR template.

### Content contributions (vocabulary / reading / translations)

Educational content is treated with extra care because it directly affects what
learners study.

**All content contributions must be reviewed before they are merged.** They do
not go straight into the shipped database.

Content lives as JSON in `content_pipeline/` and is validated and compiled by
scripts:

```bash
# 1. Validate the source JSON (schema, duplicates, answer consistency).
python content_pipeline/validate_content.py

# 2. Compile the validated JSON into the content database + manifest.
python content_pipeline/build_content_db.py
```

Content contribution rules:

- **Original only.** Do not copy official IELTS test papers, official answers,
  or any other copyrighted material. Write IELTS-*style* material yourself.
- Every reading question must include `correctAnswer`, `evidence`, `keywords`,
  `synonyms`, `logic` and `explanation` (with the synonym substitution spelled
  out).
- Vocabulary entries must include the fields listed in the PRD §"词汇系统".
- AI-generated content is **not** accepted directly. It must be validated and
  human-reviewed (`draft → validated → reviewed → published`).
- Quality beats quantity: *better 1000 correct words than 10000 wrong ones.*

Use the **Content Error** issue template to report a mistake in existing
content.

### Documentation, UI and translations

Documentation fixes, screenshots, accessibility improvements and translation
help are all welcome. For user-visible text, keep it centralized in
`lib/app/strings.dart` where practical.

---

## Reporting bugs and requesting features

Please use the GitHub issue templates:

- **Bug report** — for something that is broken.
- **Feature request** — for an idea you'd like to see.
- **Content error** — for a wrong word, passage, answer or explanation.
- **Question** — for anything else.

Include your device, OS and app version where relevant.

---

## Commit and PR guidelines

- Keep commits focused and messages descriptive.
- One logical change per pull request when possible.
- Update `CHANGELOG.md` for user-visible changes.
- Be kind and constructive in reviews.

---

## Independence and licensing

By contributing you agree that your code contributions are licensed under the
project's MIT License and your content contributions under the project's
content license. See [`LICENSE`](LICENSE) and [`LICENSE-CONTENT`](LICENSE-CONTENT).

> IELTS Free is an independent educational project and is not affiliated with
> IELTS, British Council, IDP Education, or Cambridge Assessment English.
