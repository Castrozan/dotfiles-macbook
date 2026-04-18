<extension_decision>
Skill: AI auto-detects relevance, workflow guidance, progressive disclosure.
Script: User explicit control, simple repeatable action, template-based.
</extension_decision>

<skill_format>
Skills live in agents/skills/name/SKILL.md, deployed to IA agents via home-manager. YAML frontmatter requires name and description fields. Short directory names for easy discovery. Body uses XML tags with dense prose. Script-backed skills keep logic in scripts/ subdirectory with SKILL.md as minimal entry point.
</skill_format>

<skill_discovery>
Description drives discovery. Models match semantically, so embed synonyms in prose. Every skill description is injected into every agent session; each word is a shared token tax across all interactions. Cap at 2 sentences, ~30 words. Add "Do NOT use for..." only where a sibling skill creates real confusion. All trigger information goes in the description, not the body.
</skill_discovery>

<writing_instructions>
XML tags for structure with descriptive long tag names. Dense prose in imperative voice ("Do X" not "You should do X"). Context over quantity; minimal high-signal tokens. Only add what the model doesn't already know. Challenge each piece: "Does this paragraph justify its token cost?"

Never explain what code does. The model can read it. Document what the model cannot infer: non-obvious constraints, traps where code compiles but behaves wrong, reasons behind surprising design choices, which things must stay in sync and why. If a fact is discoverable by reading the source file, it does not belong in instructions.

A stale instruction is worse than no instruction. When instructions describe code structure that later changes, the model follows the instruction over what it reads, producing confident wrong behavior. Every specific detail is a future liability. Write about forces and constraints, not about current implementation.
</writing_instructions>

<evergreen_instructions>
Instructions become stale when code changes. Write instructions that stay accurate without maintenance.

Pointers over copies: "Run the rebuild script" not "Run ./home/modules/system/scripts/rebuild".
Patterns over commands: Document patterns, not exact syntax.
Reference locations: Point to where truth lives, agent reads current state.
No hardcoded paths: Reference things by purpose, not by path.
Intent over implementation: What user wants rarely changes, how to accomplish it evolves.
Version independence: Avoid embedding versions, dates, release names.
</evergreen_instructions>

<hardskill_belongs_in_scripts>
Scripts and their --help output are the authoritative source for exact commands, flags, and syntax. Skills document what scripts cannot express: silent failure modes, non-obvious ordering constraints, domain boundaries, and which things must stay in sync. If a script's name and --help already tell the agent how to use it, the skill must not repeat that information. When a skill wraps scripts, its body should be traps and boundaries, not a reference card for the scripts' CLI interface.

Exception: genuinely non-obvious hard constraints where wrong syntax silently succeeds. Branch naming formats, socket paths that fail silently, staging rules that cause data loss. These earn their token cost because the agent cannot discover the constraint by running --help or reading source. The test: "would the agent silently produce wrong results without this line?" If no, cut it.
</hardskill_belongs_in_scripts>

<skill_authoring_preflight>
Before writing any SKILL.md, answer these questions. If any answer is "yes", revise before committing:

- Is the description over 2 sentences or ~30 words? Cut it. Every skill's description loads in every agent session.
- Does the body repeat what the frontmatter description already says? Remove it.
- Does any section belong to a different skill's responsibility?
- Are there hardcoded file paths, tokens, or environment-specific values that will go stale? Generalize to patterns.
- Would a dense two-line prose replace a verbose example block without losing clarity? Prefer density.
- Does any content exist only because raw research data was fresh in context? Strip research artifacts.
- Does any section explain what code does? Remove it. Only keep what the model cannot infer.
</skill_authoring_preflight>
