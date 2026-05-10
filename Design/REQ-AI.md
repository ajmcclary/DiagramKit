# Mermaid AI Generation Requirements

## 1. Core AI Diagram Generation

| ID     | Requirement                                                                                                                                                            | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AI-001 | The product shall allow users to generate Mermaid diagrams from natural-language prompts.                                                                              |       P1 |
| AI-002 | The AI generator shall accept freeform text descriptions of a diagram, process, architecture, workflow, data model, or plan.                                           |       P1 |
| AI-003 | The AI generator shall produce valid Mermaid syntax as its primary structured output.                                                                                  |       P1 |
| AI-004 | The AI generator shall render the generated Mermaid syntax into a visual preview.                                                                                      |       P1 |
| AI-005 | The AI generator shall allow users to edit the generated diagram after creation.                                                                                       |       P1 |
| AI-006 | The AI generator shall allow users to inspect the generated Mermaid code.                                                                                              |       P1 |
| AI-007 | The AI generator shall allow users to save the generated diagram as a new diagram.                                                                                     |       P1 |
| AI-008 | The AI generator shall support prompt-to-diagram creation without requiring the user to manually write Mermaid syntax.                                                 |       P1 |
| AI-009 | The AI generator should support both short prompts and long pasted descriptions.                                                                                       |       P2 |
| AI-010 | The AI generator should support turning notes, meeting summaries, requirements, code descriptions, database descriptions, and architecture descriptions into diagrams. |       P2 |

## 2. Supported Diagram Types

| ID     | Requirement                                                                                                                         | Priority |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AI-011 | The AI generator shall support generating flowcharts.                                                                               |       P1 |
| AI-012 | The AI generator shall support generating sequence diagrams.                                                                        |       P1 |
| AI-013 | The AI generator shall support generating ER diagrams.                                                                              |       P1 |
| AI-014 | The AI generator should support generating class diagrams.                                                                          |       P2 |
| AI-015 | The AI generator should support generating state diagrams.                                                                          |       P2 |
| AI-016 | The AI generator should support generating mind maps.                                                                               |       P2 |
| AI-017 | The AI generator should support generating timelines.                                                                               |       P2 |
| AI-018 | The AI generator should support generating user journey diagrams.                                                                   |       P2 |
| AI-019 | The AI generator should support generating Gantt charts or roadmap-style diagrams.                                                  |       P2 |
| AI-020 | The AI generator should support generating architecture diagrams where Mermaid syntax supports them.                                |       P2 |
| AI-021 | The AI generator should support generating quadrant charts, pie charts, and other Mermaid-supported diagram types when appropriate. |       P3 |
| AI-022 | The AI generator shall choose an appropriate diagram type when the user does not specify one.                                       |       P1 |
| AI-023 | The AI generator should explain why it selected a particular diagram type.                                                          |       P2 |
| AI-024 | The AI generator should allow users to explicitly override the diagram type.                                                        |       P1 |

## 3. Prompt Input Experience

| ID     | Requirement                                                                                                                             | Priority |
| ------ | --------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AI-025 | The product shall provide a prompt input field for describing the desired diagram.                                                      |       P1 |
| AI-026 | The product shall support multiline prompts.                                                                                            |       P1 |
| AI-027 | The product shall support pasting long text into the prompt field.                                                                      |       P1 |
| AI-028 | The product should provide predefined prompt cards or prompt starters.                                                                  |       P2 |
| AI-029 | Prompt starters should cover common use cases such as flowchart, ERD, roadmap, sequence diagram, architecture diagram, and process map. |       P2 |
| AI-030 | The product should provide example prompts for first-time users.                                                                        |       P2 |
| AI-031 | The product should allow users to clear the current prompt or conversation.                                                             |       P2 |
| AI-032 | The product should allow users to start a new AI diagram session.                                                                       |       P2 |
| AI-033 | The prompt field should support keyboard submission.                                                                                    |       P2 |
| AI-034 | The prompt field should preserve draft text if generation fails.                                                                        |       P1 |

## 4. AI Chat / Iterative Refinement

| ID     | Requirement                                                                                                                       | Priority |
| ------ | --------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AI-035 | The AI generator shall support iterative refinement after the first diagram is generated.                                         |       P1 |
| AI-036 | Users shall be able to ask follow-up prompts such as “make this simpler,” “add error handling,” or “show database relationships.” |       P1 |
| AI-037 | The product shall maintain conversational context during a diagram-generation session.                                            |       P1 |
| AI-038 | The product should show previous prompts and generated responses in a session history.                                            |       P2 |
| AI-039 | The product should allow users to regenerate a diagram from the same prompt.                                                      |       P2 |
| AI-040 | The product should allow users to request alternate versions of a diagram.                                                        |       P2 |
| AI-041 | The product should allow users to compare generated alternatives.                                                                 |       P3 |
| AI-042 | The product should allow users to refine style, diagram type, level of detail, naming, and grouping through follow-up prompts.    |       P2 |
| AI-043 | The product should support commands such as simplify, expand, reorganize, convert, summarize, relabel, and restyle.               |       P2 |

## 5. Generated Output

| ID     | Requirement                                                                                                | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------- | -------: |
| AI-044 | The AI generator shall produce a rendered diagram preview.                                                 |       P1 |
| AI-045 | The AI generator shall produce Mermaid source code.                                                        |       P1 |
| AI-046 | The AI generator should produce a plain-language explanation of the generated diagram.                     |       P2 |
| AI-047 | The AI generator should produce a diagram title.                                                           |       P2 |
| AI-048 | The AI generator should produce a concise diagram summary.                                                 |       P2 |
| AI-049 | The generated title should be editable.                                                                    |       P2 |
| AI-050 | The generated source should be editable.                                                                   |       P1 |
| AI-051 | The generated preview should update when the Mermaid source changes.                                       |       P1 |
| AI-052 | The product should expose “more details” or an equivalent panel showing explanation, source, and metadata. |       P2 |
| AI-053 | The product should distinguish generated content from user-authored content.                               |       P2 |

## 6. Validation and Repair

| ID     | Requirement                                                                                            | Priority |
| ------ | ------------------------------------------------------------------------------------------------------ | -------: |
| AI-054 | The AI generator shall validate generated Mermaid syntax before presenting it as a usable diagram.     |       P1 |
| AI-055 | If the generated Mermaid syntax is invalid, the product shall attempt automatic repair.                |       P1 |
| AI-056 | If automatic repair fails, the product shall show a useful error instead of a blank or broken diagram. |       P1 |
| AI-057 | The product shall preserve the failed generated source for inspection.                                 |       P1 |
| AI-058 | The product should explain why generation failed when possible.                                        |       P2 |
| AI-059 | The product should allow users to retry generation after a failure.                                    |       P1 |
| AI-060 | The product should allow users to manually edit invalid generated source.                              |       P1 |
| AI-061 | The AI generator should detect unsupported Mermaid features before saving or exporting.                |       P2 |
| AI-062 | The AI generator should avoid emitting deprecated syntax where newer syntax is preferred.              |       P2 |
| AI-063 | The AI generator should normalize generated syntax for readability.                                    |       P2 |
| AI-064 | The AI generator should avoid silently discarding user-provided details.                               |       P1 |

## 7. Editing Handoff

| ID     | Requirement                                                                                                      | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------- | -------: |
| AI-065 | Users shall be able to open an AI-generated diagram in the main editor.                                          |       P1 |
| AI-066 | Users shall be able to continue editing generated diagrams as normal diagrams.                                   |       P1 |
| AI-067 | Users shall be able to move from AI generation to code editing.                                                  |       P1 |
| AI-068 | Users should be able to move from AI generation to visual editing when the diagram type is visually supported.   |       P2 |
| AI-069 | If the generated diagram type is not visually editable, the product shall fall back to code editing and preview. |       P1 |
| AI-070 | The product shall not lose AI-generated source when switching editing modes.                                     |       P1 |
| AI-071 | The product should preserve AI session history after the generated diagram is saved.                             |       P2 |
| AI-072 | The product should show whether a diagram was originally AI-generated.                                           |       P3 |

## 8. Export and Sharing

| ID     | Requirement                                                                                      | Priority |
| ------ | ------------------------------------------------------------------------------------------------ | -------: |
| AI-073 | Users shall be able to export AI-generated diagrams.                                             |       P1 |
| AI-074 | Export shall support Mermaid source/MMD.                                                         |       P1 |
| AI-075 | Export shall support SVG.                                                                        |       P1 |
| AI-076 | Export shall support PNG.                                                                        |       P1 |
| AI-077 | Export should preserve generated styling and theme choices.                                      |       P2 |
| AI-078 | Users should be able to copy generated Mermaid source to the clipboard.                          |       P1 |
| AI-079 | Users should be able to copy generated diagram images to the clipboard.                          |       P2 |
| AI-080 | Users should be able to share generated diagrams through links where cloud sharing is supported. |       P2 |
| AI-081 | Shared AI-generated diagrams should respect diagram permissions.                                 |       P2 |

## 9. Diagram Conversion

| ID     | Requirement                                                                                              | Priority |
| ------ | -------------------------------------------------------------------------------------------------------- | -------: |
| AI-082 | The AI generator should allow users to convert one diagram type into another when semantically possible. |       P2 |
| AI-083 | Users should be able to ask AI to convert a flowchart into a sequence diagram.                           |       P2 |
| AI-084 | Users should be able to ask AI to convert a textual schema into an ER diagram.                           |       P2 |
| AI-085 | Users should be able to ask AI to convert requirements into a process map.                               |       P2 |
| AI-086 | Users should be able to ask AI to convert a process into a timeline or roadmap.                          |       P2 |
| AI-087 | The product should warn when conversion will lose information.                                           |       P2 |
| AI-088 | The product should preserve the original diagram before applying a conversion.                           |       P1 |

## 10. Source-Aware Generation

| ID     | Requirement                                                                                                             | Priority |
| ------ | ----------------------------------------------------------------------------------------------------------------------- | -------: |
| AI-089 | The AI generator should support generating diagrams from pasted code snippets.                                          |       P2 |
| AI-090 | The AI generator should support generating diagrams from pasted database schemas.                                       |       P2 |
| AI-091 | The AI generator should support generating diagrams from API descriptions.                                              |       P2 |
| AI-092 | The AI generator should support generating diagrams from user stories or requirements.                                  |       P2 |
| AI-093 | The AI generator should support generating diagrams from meeting notes or planning notes.                               |       P2 |
| AI-094 | The AI generator should support generating diagrams from incident reports or postmortems.                               |       P2 |
| AI-095 | The AI generator should allow users to specify the desired level of abstraction.                                        |       P2 |
| AI-096 | The AI generator should allow users to specify whether to include implementation details, high-level concepts, or both. |       P2 |

## 11. AI-Assisted Editing Commands

| ID     | Requirement                                                                                                                                | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------ | -------: |
| AI-097 | Users should be able to ask AI to add nodes.                                                                                               |       P2 |
| AI-098 | Users should be able to ask AI to remove nodes.                                                                                            |       P2 |
| AI-099 | Users should be able to ask AI to rename nodes.                                                                                            |       P2 |
| AI-100 | Users should be able to ask AI to regroup diagram sections.                                                                                |       P2 |
| AI-101 | Users should be able to ask AI to add missing steps.                                                                                       |       P2 |
| AI-102 | Users should be able to ask AI to detect gaps in a process.                                                                                |       P2 |
| AI-103 | Users should be able to ask AI to simplify a complex diagram.                                                                              |       P2 |
| AI-104 | Users should be able to ask AI to make a diagram more detailed.                                                                            |       P2 |
| AI-105 | Users should be able to ask AI to improve labels.                                                                                          |       P2 |
| AI-106 | Users should be able to ask AI to make naming more consistent.                                                                             |       P2 |
| AI-107 | Users should be able to ask AI to apply a specific audience framing, such as executive, engineering, product, support, or customer-facing. |       P2 |
| AI-108 | Users should be able to ask AI to generate documentation text from a diagram.                                                              |       P3 |

## 12. Prompt Templates and Use-Case Library

| ID     | Requirement                                                         | Priority |
| ------ | ------------------------------------------------------------------- | -------: |
| AI-109 | The product should include a prompt template library.               |       P2 |
| AI-110 | Prompt templates should be categorized by diagram type.             |       P2 |
| AI-111 | Prompt templates should be categorized by job-to-be-done.           |       P2 |
| AI-112 | The product should include templates for software architecture.     |       P2 |
| AI-113 | The product should include templates for database modeling.         |       P2 |
| AI-114 | The product should include templates for process mapping.           |       P2 |
| AI-115 | The product should include templates for product roadmaps.          |       P2 |
| AI-116 | The product should include templates for troubleshooting workflows. |       P2 |
| AI-117 | The product should include templates for onboarding flows.          |       P3 |
| AI-118 | The product should allow users to save custom prompts.              |       P3 |
| AI-119 | The product should allow teams to share approved prompt templates.  |       P3 |

## 13. Diagram Quality Controls

| ID     | Requirement                                                                                         | Priority |
| ------ | --------------------------------------------------------------------------------------------------- | -------: |
| AI-120 | The AI generator should optimize generated diagrams for readability.                                |       P1 |
| AI-121 | The AI generator should avoid creating overly dense diagrams by default.                            |       P1 |
| AI-122 | The AI generator should use concise labels.                                                         |       P1 |
| AI-123 | The AI generator should avoid duplicate nodes unless intentional.                                   |       P1 |
| AI-124 | The AI generator should avoid disconnected elements unless requested.                               |       P2 |
| AI-125 | The AI generator should use consistent terminology.                                                 |       P2 |
| AI-126 | The AI generator should produce diagrams that render cleanly at typical viewport sizes.             |       P2 |
| AI-127 | The AI generator should recommend splitting large diagrams into multiple diagrams when appropriate. |       P2 |
| AI-128 | The AI generator should detect when a prompt is too broad and propose a scoped version.             |       P2 |
| AI-129 | The AI generator should support “high-level,” “medium detail,” and “detailed” generation modes.     |       P2 |

## 14. Theme and Style Generation

| ID     | Requirement                                                                                                                    | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------------------------ | -------: |
| AI-130 | The AI generator should allow users to request a visual style or theme.                                                        |       P2 |
| AI-131 | The AI generator should preserve compatibility with Mermaid-supported themes.                                                  |       P1 |
| AI-132 | The AI generator should not depend on unsupported styling syntax.                                                              |       P1 |
| AI-133 | The AI generator should support style-related prompts such as “make this presentation-friendly” or “make this more technical.” |       P2 |
| AI-134 | The AI generator should distinguish semantic changes from visual styling changes.                                              |       P2 |
| AI-135 | The AI generator should allow users to apply style changes without changing the diagram’s meaning.                             |       P2 |

## 15. AI Credits, Quotas, and Plan Gating

| ID     | Requirement                                                                                                                                          | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AI-136 | The product shall support plan-gated AI access.                                                                                                      |       P1 |
| AI-137 | The product shall support AI credit accounting if the commercial model uses credits.                                                                 |       P1 |
| AI-138 | The product shall show remaining AI credits where applicable.                                                                                        |       P2 |
| AI-139 | The product shall gracefully handle exhausted credits.                                                                                               |       P1 |
| AI-140 | The product shall show upgrade messaging when users attempt a gated AI action.                                                                       |       P2 |
| AI-141 | The product should distinguish free, limited, paid, and unlimited AI access states.                                                                  |       P2 |
| AI-142 | The product should avoid hard-coding credit amounts because public Mermaid pricing information has shown inconsistencies across pages and over time. |       P1 |
| AI-143 | The product should fetch plan and entitlement data from a configurable source.                                                                       |       P1 |
| AI-144 | The product should log AI usage events for audit and billing reconciliation.                                                                         |       P2 |
| AI-145 | The product should expose usage history to administrators where team plans exist.                                                                    |       P3 |

## 16. Privacy and Data Handling

| ID     | Requirement                                                                                                                              | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AI-146 | The product shall clearly disclose that prompts and diagram content may be sent to an AI service when cloud AI generation is used.       |       P1 |
| AI-147 | The product shall distinguish local diagram editing from cloud AI generation.                                                            |       P1 |
| AI-148 | The product shall provide clear privacy messaging before users submit sensitive content to AI.                                           |       P1 |
| AI-149 | The product should support disabling AI features for sensitive workspaces.                                                               |       P2 |
| AI-150 | The product should support organization-level AI policy controls.                                                                        |       P2 |
| AI-151 | The product should allow administrators to control whether prompts may be used for training, where the vendor supports that distinction. |       P2 |
| AI-152 | The product should clearly communicate plan-specific privacy differences.                                                                |       P1 |
| AI-153 | The product should support a “do not submit secrets” warning near the prompt box.                                                        |       P2 |
| AI-154 | The product should redact or warn about likely secrets in pasted prompts.                                                                |       P2 |
| AI-155 | The product should maintain prompt history only according to user or organization retention settings.                                    |       P2 |

## 17. Security and Enterprise Controls

| ID     | Requirement                                                                                                            | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------- | -------: |
| AI-156 | AI generation shall respect workspace permissions.                                                                     |       P1 |
| AI-157 | AI-generated diagrams shall inherit the permissions of the workspace or project where they are saved.                  |       P1 |
| AI-158 | Users without edit permission shall not be able to overwrite saved diagrams with AI-generated changes.                 |       P1 |
| AI-159 | The product should support disabling AI generation for external collaborators.                                         |       P2 |
| AI-160 | The product should support audit logging for AI prompt submission, diagram generation, save, export, and share events. |       P2 |
| AI-161 | Enterprise administrators should be able to enable or disable AI features globally.                                    |       P2 |
| AI-162 | Enterprise administrators should be able to configure approved AI models or providers where supported.                 |       P3 |
| AI-163 | Enterprise administrators should be able to review AI usage by user, project, and workspace.                           |       P3 |

## 18. Collaboration Around AI Output

| ID     | Requirement                                                                                       | Priority |
| ------ | ------------------------------------------------------------------------------------------------- | -------: |
| AI-164 | Users should be able to share AI-generated diagrams with collaborators.                           |       P2 |
| AI-165 | Collaborators should be able to comment on AI-generated diagrams where commenting is supported.   |       P2 |
| AI-166 | Collaborators should be able to view the generated source where they have permission.             |       P2 |
| AI-167 | The product should preserve AI generation context when sharing a diagram internally.              |       P3 |
| AI-168 | The product should allow users to mark generated diagrams as drafts before publishing or sharing. |       P2 |
| AI-169 | The product should allow reviewers to approve or reject AI-generated diagrams in team workflows.  |       P3 |

## 19. Versioning and History

| ID     | Requirement                                                                                       | Priority |
| ------ | ------------------------------------------------------------------------------------------------- | -------: |
| AI-170 | The product shall preserve the saved generated diagram as a revision.                             |       P1 |
| AI-171 | The product should preserve the prompt that produced a generated diagram.                         |       P2 |
| AI-172 | The product should preserve follow-up prompts as part of AI session history.                      |       P2 |
| AI-173 | Users should be able to restore a previous generated version.                                     |       P2 |
| AI-174 | Users should be able to compare versions generated from different prompts.                        |       P3 |
| AI-175 | AI-assisted edits should be distinguishable from manual edits in history.                         |       P3 |
| AI-176 | The product should allow users to discard AI output without affecting the existing saved diagram. |       P1 |

## 20. Integrations and AI Assistants

| ID     | Requirement                                                                                                                  | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------------- | -------: |
| AI-177 | The product should support AI generation through first-party app UI.                                                         |       P1 |
| AI-178 | The product should support AI generation through integrations where available.                                               |       P2 |
| AI-179 | The product should support assistant-mediated diagram creation through an MCP-style integration.                             |       P2 |
| AI-180 | The integration layer should support validating Mermaid syntax.                                                              |       P1 |
| AI-181 | The integration layer should support rendering Mermaid diagrams.                                                             |       P1 |
| AI-182 | The integration layer should support creating diagrams in a Mermaid account or workspace where authenticated APIs permit it. |       P2 |
| AI-183 | The integration layer should support fetching existing diagrams where authenticated APIs permit it.                          |       P2 |
| AI-184 | The integration layer should support updating diagrams where authenticated APIs permit it.                                   |       P2 |
| AI-185 | The product should avoid assuming undocumented REST, GraphQL, webhook, or SLA capabilities.                                  |       P1 |

## 21. Error States

| ID     | Requirement                                                                                                                              | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AI-186 | The product shall show a loading state during AI generation.                                                                             |       P1 |
| AI-187 | The product shall show an error when generation fails.                                                                                   |       P1 |
| AI-188 | The product shall show an error when generated Mermaid syntax cannot be parsed.                                                          |       P1 |
| AI-189 | The product shall show an error when the generated diagram cannot be rendered.                                                           |       P1 |
| AI-190 | The product shall show an error when the user lacks AI permission.                                                                       |       P1 |
| AI-191 | The product shall show an error when the user has exhausted AI credits.                                                                  |       P1 |
| AI-192 | The product shall show an error when the AI service is unavailable.                                                                      |       P1 |
| AI-193 | The product should distinguish between prompt errors, syntax errors, render errors, permission errors, quota errors, and network errors. |       P2 |
| AI-194 | The product should allow retrying generation after recoverable failures.                                                                 |       P1 |
| AI-195 | The product should avoid charging or consuming credits for failed generations where the backend supports that distinction.               |       P2 |

## 22. Accessibility

| ID     | Requirement                                                                                          | Priority |
| ------ | ---------------------------------------------------------------------------------------------------- | -------: |
| AI-196 | The AI prompt input shall be keyboard accessible.                                                    |       P1 |
| AI-197 | Generated diagram controls shall be keyboard accessible.                                             |       P1 |
| AI-198 | Loading, success, and error states shall be announced to assistive technologies.                     |       P1 |
| AI-199 | The product should provide accessible labels for generated diagrams.                                 |       P2 |
| AI-200 | The AI generator should produce diagram titles and descriptions suitable for accessibility metadata. |       P2 |
| AI-201 | The AI chat history should be navigable with assistive technologies.                                 |       P2 |
| AI-202 | The product should not rely on color alone to communicate generation status or errors.               |       P1 |

## 23. Recommended MVP Scope

For an MVP AI generation feature, I would include:

| Area            | MVP Requirement                                                                          |
| --------------- | ---------------------------------------------------------------------------------------- |
| Input           | Freeform prompt input with multiline support                                             |
| Output          | Mermaid source plus rendered preview                                                     |
| Diagram types   | Flowchart, sequence diagram, ER diagram                                                  |
| Validation      | Parse generated syntax before saving                                                     |
| Repair          | Automatic retry/repair when syntax is invalid                                            |
| Editing handoff | Open generated diagram in the normal editor                                              |
| Export          | Copy source, export SVG, export PNG                                                      |
| History         | Preserve prompt and generated result                                                     |
| Error handling  | Clear states for network failure, invalid syntax, quota exhausted, and permission denied |
| Privacy         | Clear warning that prompts are submitted to AI/cloud processing                          |
| Plan gating     | Configurable AI availability and credits                                                 |

## 24. Recommended Advanced Scope

After MVP, the strongest differentiators would be:

| Area                  | Advanced Requirement                                                  |
| --------------------- | --------------------------------------------------------------------- |
| Iteration             | Conversational refinement with prompt history                         |
| Alternatives          | Generate 2–4 candidate diagrams from one prompt                       |
| Conversion            | Convert between diagram types                                         |
| Quality               | Diagram linting and readability scoring                               |
| Source-aware input    | Generate from code, database schema, API contract, or requirements    |
| Collaboration         | AI-generated draft review and approval                                |
| Enterprise            | Admin AI controls, audit logs, retention policy, no-training controls |
| Templates             | Organization-approved prompt templates                                |
| Assistant integration | MCP-style AI assistant bridge                                         |
| Presentation workflow | Generate a diagram plus speaker-ready explanation                     |

## 25. Key Product Caveat

The AI generator should not be treated as a magic image generator. It should be treated as a **Mermaid source generator with validation, rendering, repair, and editing handoff**.

That means the ideal lifecycle is:

```text
Prompt
→ AI-generated Mermaid source
→ Syntax validation
→ Rendered preview
→ Optional repair
→ User refinement
→ Save as editable diagram
→ Export/share/present
```

The most important design rule: **never let the AI output become a dead-end image.** The generated result should remain editable Mermaid source.
