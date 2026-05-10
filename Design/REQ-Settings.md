# Mermaid Settings Requirements

## 1. Core Settings Scope

| ID      | Requirement                                                                                                                           | Priority |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| SET-001 | The product shall provide a Settings area for managing user, editor, workspace, collaboration, billing, AI, and security preferences. |       P1 |
| SET-002 | Settings shall distinguish between personal settings, diagram/editor settings, workspace settings, and admin settings.                |       P1 |
| SET-003 | Settings shall only show controls the current user has permission to view or modify.                                                  |       P1 |
| SET-004 | Settings should expose plan-gated controls with clear upgrade or permission messaging.                                                |       P2 |
| SET-005 | Settings should avoid mixing local editor preferences with organization-wide policy controls.                                         |       P1 |
| SET-006 | Settings should clearly indicate whether a setting applies globally, per workspace, per project, or per diagram.                      |       P1 |
| SET-007 | Settings should provide search across available settings.                                                                             |       P2 |
| SET-008 | Settings should support deep links to specific settings sections.                                                                     |       P2 |

## 2. Settings Navigation

| ID      | Requirement                                                                                                                                                                                                 | Priority |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| SET-009 | Settings shall provide a clear category navigation structure.                                                                                                                                               |       P1 |
| SET-010 | Settings should include categories for Account, Appearance, Editor, Diagram Defaults, Library, Sharing, Collaboration, AI, Export, Presentations, Integrations, Billing, Workspace, Security, and Advanced. |       P2 |
| SET-011 | Settings should show user-facing settings separately from administrator-only settings.                                                                                                                      |       P1 |
| SET-012 | Settings should preserve the user’s position when navigating between sections.                                                                                                                              |       P2 |
| SET-013 | Settings should support contextual entry from related product areas, such as opening diagram sharing settings from the editor Share button.                                                                 |       P2 |
| SET-014 | Settings should show unsaved-change warnings before leaving a section with pending edits.                                                                                                                   |       P1 |

## 3. Account Settings

| ID      | Requirement                                                                                               | Priority |
| ------- | --------------------------------------------------------------------------------------------------------- | -------: |
| SET-015 | Users shall be able to view their account profile information.                                            |       P1 |
| SET-016 | Users should be able to update their display name.                                                        |       P2 |
| SET-017 | Users should be able to update their avatar or profile image.                                             |       P3 |
| SET-018 | Users should be able to view their account email address.                                                 |       P1 |
| SET-019 | Users should be able to manage email preferences.                                                         |       P2 |
| SET-020 | Users should be able to sign out from Settings.                                                           |       P1 |
| SET-021 | Users should be able to delete or request deletion of their account where policy allows.                  |       P2 |
| SET-022 | Account deletion shall warn users about diagrams, shared content, workspaces, and ownership implications. |       P1 |

## 4. Appearance Settings

| ID      | Requirement                                                                                         | Priority |
| ------- | --------------------------------------------------------------------------------------------------- | -------: |
| SET-023 | Users shall be able to choose the application appearance.                                           |       P1 |
| SET-024 | Appearance settings shall support light mode.                                                       |       P1 |
| SET-025 | Appearance settings shall support dark mode.                                                        |       P1 |
| SET-026 | Appearance settings should support system/default appearance.                                       |       P2 |
| SET-027 | Appearance settings should apply to the app/editor chrome separately from diagram rendering themes. |       P1 |
| SET-028 | Appearance settings should preview the selected theme before applying it.                           |       P2 |
| SET-029 | Appearance settings should not unintentionally modify saved diagram source.                         |       P1 |

## 5. Editor Behavior Settings

Mermaid’s editor docs identify **Autosync** and **Pan & Zoom** inside the editor More Options menu, and also identify light/dark mode, text editor, rendered preview, local timeline, theme selector, export, and sharing as editor features. ([Mermaid][1])

| ID      | Requirement                                                                                                           | Priority |
| ------- | --------------------------------------------------------------------------------------------------------------------- | -------: |
| SET-030 | Users shall be able to configure editor behavior preferences.                                                         |       P1 |
| SET-031 | Users should be able to enable or disable autosync/live preview.                                                      |       P1 |
| SET-032 | Autosync settings should explain that diagrams update automatically while typing.                                     |       P2 |
| SET-033 | Users should be able to enable or disable pan and zoom behavior.                                                      |       P1 |
| SET-034 | Users should be able to choose a default editor mode where supported, such as Code, Visual Editor, Whiteboard, or AI. |       P2 |
| SET-035 | Users should be able to choose whether new diagrams open with source visible, preview visible, or split view.         |       P2 |
| SET-036 | Users should be able to configure editor font size.                                                                   |       P2 |
| SET-037 | Users should be able to configure editor line wrapping.                                                               |       P2 |
| SET-038 | Users should be able to configure tab width or indentation behavior.                                                  |       P3 |
| SET-039 | Users should be able to configure whether source formatting/prettification occurs automatically.                      |       P2 |
| SET-040 | Settings should warn that Visual Editor usage may prettify or restructure Mermaid source where applicable.            |       P1 |
| SET-041 | Users should be able to configure whether the editor opens diagram documentation in a new tab or internal panel.      |       P3 |
| SET-042 | Users should be able to reset editor behavior settings to defaults.                                                   |       P2 |

## 6. Diagram Theme Defaults

Mermaid Chart’s editor supports themes including **Mermaid Chart, Default, Forest, Base, Dark, and Neutral**; the Whiteboard docs also reference additional themes/look controls such as Mermaid Chart, Neo, Neo dark, Default, Forest, Base, Dark, and Neutral. ([Mermaid][1])

| ID      | Requirement                                                                                                          | Priority |
| ------- | -------------------------------------------------------------------------------------------------------------------- | -------: |
| SET-043 | Settings shall allow users to choose a default diagram theme.                                                        |       P1 |
| SET-044 | Theme settings should support Mermaid Chart, Default, Forest, Base, Dark, and Neutral.                               |       P1 |
| SET-045 | Theme settings should support additional product themes where available, such as Neo and Neo dark.                   |       P2 |
| SET-046 | Theme settings shall distinguish diagram theme from app appearance.                                                  |       P1 |
| SET-047 | Users should be able to preview diagram themes before applying them.                                                 |       P2 |
| SET-048 | Users should be able to choose whether default theme applies to new diagrams only or also updates existing diagrams. |       P2 |
| SET-049 | Settings should prevent accidental bulk restyling of existing diagrams.                                              |       P1 |
| SET-050 | Settings should show whether a diagram uses a global default, workspace default, or diagram-specific override.       |       P2 |
| SET-051 | Users should be able to reset diagram theme defaults.                                                                |       P2 |

## 7. Diagram Rendering Defaults

| ID      | Requirement                                                                                                                      | Priority |
| ------- | -------------------------------------------------------------------------------------------------------------------------------- | -------: |
| SET-052 | Settings should allow users to configure default rendering behavior for new diagrams.                                            |       P2 |
| SET-053 | Users should be able to set default diagram direction where supported by the diagram type.                                       |       P3 |
| SET-054 | Users should be able to configure default look/style where the product supports “Look” options.                                  |       P2 |
| SET-055 | Users should be able to configure whether rendered diagrams auto-fit to the available viewport.                                  |       P2 |
| SET-056 | Users should be able to configure default zoom behavior.                                                                         |       P2 |
| SET-057 | Users should be able to configure whether diagrams open centered, fit-to-screen, or at last-viewed zoom.                         |       P2 |
| SET-058 | Users should be able to configure whether thumbnails are generated automatically for Library items.                              |       P3 |
| SET-059 | Rendering defaults shall not override diagram-specific source configuration unless the user explicitly chooses to apply changes. |       P1 |

## 8. Visual Editor Settings

| ID      | Requirement                                                                                                  | Priority |
| ------- | ------------------------------------------------------------------------------------------------------------ | -------: |
| SET-060 | Settings should allow users to configure Visual Editor preferences where the Visual Editor is available.     |       P2 |
| SET-061 | Users should be able to choose whether Visual Editor is enabled by default for supported diagram types.      |       P2 |
| SET-062 | Settings should disclose that the Visual Editor currently supports flowcharts where that limitation applies. |       P1 |
| SET-063 | Settings should disclose that Visual Editor changes may prettify or regenerate Mermaid code.                 |       P1 |
| SET-064 | Users should be able to configure whether a warning appears before entering Visual Editor mode.              |       P2 |
| SET-065 | Users should be able to configure default node styling for visually-created nodes.                           |       P3 |
| SET-066 | Users should be able to configure default edge styling for visually-created edges.                           |       P3 |
| SET-067 | Users should be able to reset Visual Editor preferences to defaults.                                         |       P2 |

## 9. Whiteboard Settings

Mermaid’s Whiteboard docs describe **Global settings** for Theme and Look, a Timeline section with restore and clear history, export controls, undo/redo, pan, zoom, reset pan/zoom, full screen, sharing, and comments. ([Mermaid][2])

| ID      | Requirement                                                                                                     | Priority |
| ------- | --------------------------------------------------------------------------------------------------------------- | -------: |
| SET-068 | Settings should allow users to configure Whiteboard behavior where Whiteboard is available.                     |       P2 |
| SET-069 | Users should be able to configure default Whiteboard theme.                                                     |       P2 |
| SET-070 | Users should be able to configure default Whiteboard look/style.                                                |       P2 |
| SET-071 | Users should be able to configure whether Whiteboard starts in pan, select, or edit mode.                       |       P3 |
| SET-072 | Users should be able to configure default zoom behavior for Whiteboard.                                         |       P2 |
| SET-073 | Users should be able to configure whether multi-select hints are shown.                                         |       P3 |
| SET-074 | Users should be able to clear local Whiteboard history where supported.                                         |       P2 |
| SET-075 | Clearing history shall require confirmation.                                                                    |       P1 |
| SET-076 | Settings shall explain whether clearing timeline/history affects only local history or shared revision history. |       P1 |

## 10. Local Timeline and Revision Settings

Mermaid’s editor docs describe a **Local Timeline** that displays diagram revision history, supports reverting to a previous version, and autosaves edits. ([Mermaid][1])

| ID      | Requirement                                                                                      | Priority |
| ------- | ------------------------------------------------------------------------------------------------ | -------: |
| SET-077 | Settings should allow users to configure local timeline and revision-history preferences.        |       P2 |
| SET-078 | Users should be able to view whether autosave is enabled.                                        |       P1 |
| SET-079 | Users should be able to understand that edits are saved automatically where autosave is enabled. |       P1 |
| SET-080 | Users should be able to configure local revision retention where supported.                      |       P3 |
| SET-081 | Users should be able to clear local timeline/history where supported.                            |       P2 |
| SET-082 | Clearing local history shall require confirmation.                                               |       P1 |
| SET-083 | Settings shall distinguish local timeline history from cloud revision history or audit logs.     |       P1 |
| SET-084 | Settings should allow users to opt into or out of showing timeline prompts after major edits.    |       P3 |

## 11. Sharing Settings

Mermaid’s editor docs state that sharing allows users to set diagram access, share an Editor link, or share an SVG link; Whiteboard docs also describe inviting by email, setting permissions, sharing Editor links, and sharing SVG links. ([Mermaid][1])

| ID      | Requirement                                                                                     | Priority |
| ------- | ----------------------------------------------------------------------------------------------- | -------: |
| SET-085 | Settings shall allow users to configure default sharing behavior for diagrams they create.      |       P1 |
| SET-086 | Settings should allow users to choose the default access level for new diagrams.                |       P2 |
| SET-087 | Settings should allow users to configure whether new diagrams are private by default.           |       P1 |
| SET-088 | Settings should allow users to manage whether Editor links can be created.                      |       P2 |
| SET-089 | Settings should allow users to manage whether SVG links can be created.                         |       P2 |
| SET-090 | Settings should allow users to configure whether link sharing is allowed for personal diagrams. |       P2 |
| SET-091 | Settings should allow workspace admins to restrict external sharing.                            |       P1 |
| SET-092 | Settings should allow workspace admins to require explicit permission before external sharing.  |       P2 |
| SET-093 | Settings should allow users to revoke active share links.                                       |       P2 |
| SET-094 | Settings should expose a list of currently shared diagrams where useful.                        |       P3 |
| SET-095 | Settings shall never expose private share URLs to unauthorized users.                           |       P1 |

## 12. Collaboration Settings

Mermaid’s product and pricing pages describe real-time collaboration, view/comment collaboration, co-editing, external sharing, comments, unlimited viewer seats on higher plans, and collaboration being plan-gated. ([Mermaid][3])

| ID      | Requirement                                                                                         | Priority |
| ------- | --------------------------------------------------------------------------------------------------- | -------: |
| SET-096 | Settings should allow users to manage collaboration preferences.                                    |       P2 |
| SET-097 | Settings should allow users to configure comment notifications.                                     |       P2 |
| SET-098 | Settings should allow users to configure mention notifications.                                     |       P2 |
| SET-099 | Settings should allow users to configure whether collaborators can comment by default.              |       P2 |
| SET-100 | Settings should allow workspace admins to control whether co-editing is enabled.                    |       P2 |
| SET-101 | Settings should allow workspace admins to control whether external collaborators are allowed.       |       P1 |
| SET-102 | Settings should show collaboration features based on the current plan.                              |       P1 |
| SET-103 | Settings should explain when collaboration is view/comment-only versus co-editing.                  |       P1 |
| SET-104 | Settings should support collaborator role definitions such as owner, editor, commenter, and viewer. |       P2 |
| SET-105 | Settings should expose viewer-seat and collaborator limits where plan rules require it.             |       P2 |

## 13. AI Settings

Mermaid’s pricing page lists AI credits by plan, and the editor docs describe an AI chatbot where users prompt and refine until they receive the desired diagram. ([Mermaid][3])

| ID      | Requirement                                                                                        | Priority |
| ------- | -------------------------------------------------------------------------------------------------- | -------: |
| SET-106 | Settings shall show whether AI features are enabled for the current user.                          |       P1 |
| SET-107 | Settings shall show AI usage or remaining AI credits where applicable.                             |       P1 |
| SET-108 | Settings should show AI credit reset period where applicable.                                      |       P2 |
| SET-109 | Settings should allow users to manage AI prompt history preferences.                               |       P2 |
| SET-110 | Settings should allow users to clear local AI prompt history where supported.                      |       P2 |
| SET-111 | Settings should disclose whether AI prompts may be sent to cloud services.                         |       P1 |
| SET-112 | Settings should disclose whether AI prompts are stored.                                            |       P1 |
| SET-113 | Settings should disclose whether AI prompts may be used for model improvement, where applicable.   |       P1 |
| SET-114 | Settings should allow workspace admins to enable or disable AI features.                           |       P2 |
| SET-115 | Settings should allow workspace admins to restrict AI usage for sensitive workspaces.              |       P2 |
| SET-116 | Settings should allow workspace admins to view AI usage by user where supported.                   |       P3 |
| SET-117 | Settings should provide upgrade messaging when AI is plan-limited or credits are exhausted.        |       P1 |
| SET-118 | Settings should avoid hard-coding public AI credit values because pricing/plan details can change. |       P1 |

## 14. Code Snippets Settings

Mermaid’s editor docs identify **Code Snippets** as beta and available for Flowchart and Sequence Diagram. ([Mermaid][1])

| ID      | Requirement                                                                             | Priority |
| ------- | --------------------------------------------------------------------------------------- | -------: |
| SET-119 | Settings should allow users to enable or disable beta code snippets where available.    |       P3 |
| SET-120 | Settings should disclose which diagram types support code snippets.                     |       P2 |
| SET-121 | Settings should allow users to choose whether snippets appear in the editor by default. |       P3 |
| SET-122 | Settings should allow teams to define approved snippets where team features exist.      |       P3 |
| SET-123 | Settings should label beta functionality clearly.                                       |       P1 |

## 15. Export Settings

Mermaid’s editor docs describe exporting diagrams as PNG or SVG and exporting diagram code as MMD; Whiteboard docs also list PNG and SVG export. ([Mermaid][1])

| ID      | Requirement                                                                                                             | Priority |
| ------- | ----------------------------------------------------------------------------------------------------------------------- | -------: |
| SET-124 | Settings should allow users to configure default export format.                                                         |       P2 |
| SET-125 | Export settings should support PNG as an export option.                                                                 |       P1 |
| SET-126 | Export settings should support SVG as an export option.                                                                 |       P1 |
| SET-127 | Export settings should support MMD/Mermaid source export where source export is available.                              |       P1 |
| SET-128 | Users should be able to configure default export filename behavior.                                                     |       P3 |
| SET-129 | Users should be able to configure whether exported diagrams use current theme, diagram theme, or export-specific theme. |       P2 |
| SET-130 | Users should be able to configure default export scale/resolution where supported.                                      |       P3 |
| SET-131 | Settings should allow workspace admins to restrict export formats where policy requires.                                |       P3 |
| SET-132 | Export settings shall respect diagram permissions.                                                                      |       P1 |

## 16. Presentation Settings

| ID      | Requirement                                                                                                              | Priority |
| ------- | ------------------------------------------------------------------------------------------------------------------------ | -------: |
| SET-133 | Settings should allow users to configure presentation defaults.                                                          |       P2 |
| SET-134 | Users should be able to choose default presentation theme where supported.                                               |       P3 |
| SET-135 | Users should be able to configure whether presentation mode opens full-screen by default.                                |       P2 |
| SET-136 | Users should be able to configure slide navigation preferences.                                                          |       P3 |
| SET-137 | Users should be able to configure whether diagrams remain linked or snapshot-based in new presentations where supported. |       P3 |
| SET-138 | Settings should allow workspace admins to control presentation sharing permissions.                                      |       P2 |
| SET-139 | Settings should expose whether Presentations are available on the current plan.                                          |       P2 |

## 17. Library Settings

| ID      | Requirement                                                                                                           | Priority |
| ------- | --------------------------------------------------------------------------------------------------------------------- | -------: |
| SET-140 | Settings should allow users to configure default Library view.                                                        |       P2 |
| SET-141 | Users should be able to choose grid or list as the default Library layout.                                            |       P2 |
| SET-142 | Users should be able to choose default Library sort order.                                                            |       P2 |
| SET-143 | Users should be able to choose whether recent diagrams appear on the Library home screen.                             |       P3 |
| SET-144 | Users should be able to configure thumbnail visibility.                                                               |       P3 |
| SET-145 | Users should be able to configure whether shared-with-me content appears in the main Library by default.              |       P3 |
| SET-146 | Settings should allow workspace admins to configure default project/folder rules where workspace organization exists. |       P3 |

## 18. Activity Feed and Notification Settings

| ID      | Requirement                                                                                                     | Priority |
| ------- | --------------------------------------------------------------------------------------------------------------- | -------: |
| SET-147 | Settings should allow users to configure activity notifications.                                                |       P2 |
| SET-148 | Users should be able to enable or disable email notifications for comments.                                     |       P2 |
| SET-149 | Users should be able to enable or disable email notifications for mentions.                                     |       P2 |
| SET-150 | Users should be able to enable or disable notifications for shared diagram activity.                            |       P2 |
| SET-151 | Users should be able to configure notifications for workspace invitations.                                      |       P2 |
| SET-152 | Users should be able to configure notifications for ownership or permission changes.                            |       P2 |
| SET-153 | Workspace admins should be able to configure whether security-sensitive activity generates admin notifications. |       P3 |
| SET-154 | Settings should distinguish notification preferences from the permanent activity/audit history.                 |       P1 |

## 19. Workspace Settings

Mermaid positions the product around one workspace for diagrams, AI, code editing, visual editing, plugins, and presentations; pricing also includes team/project creation and unlimited viewer seats on higher plans. ([Mermaid][4])

| ID      | Requirement                                                                                   | Priority |
| ------- | --------------------------------------------------------------------------------------------- | -------: |
| SET-155 | Workspace admins shall be able to view workspace details.                                     |       P1 |
| SET-156 | Workspace admins should be able to rename the workspace.                                      |       P2 |
| SET-157 | Workspace admins should be able to manage workspace members.                                  |       P1 |
| SET-158 | Workspace admins should be able to invite members by email.                                   |       P1 |
| SET-159 | Workspace admins should be able to remove members.                                            |       P1 |
| SET-160 | Workspace admins should be able to change member roles.                                       |       P1 |
| SET-161 | Workspace settings should support team and project creation where available.                  |       P2 |
| SET-162 | Workspace settings should expose viewer-seat behavior where available.                        |       P2 |
| SET-163 | Workspace settings should show workspace plan and entitlement state.                          |       P1 |
| SET-164 | Workspace settings should show whether external sharing, co-editing, SSO, and AI are enabled. |       P1 |

## 20. Projects and Team Settings

| ID      | Requirement                                                                                             | Priority |
| ------- | ------------------------------------------------------------------------------------------------------- | -------: |
| SET-165 | Settings should allow workspace admins to manage projects.                                              |       P2 |
| SET-166 | Settings should allow workspace admins to create projects where the plan supports projects.             |       P2 |
| SET-167 | Settings should allow workspace admins to rename projects.                                              |       P2 |
| SET-168 | Settings should allow workspace admins to archive or delete projects.                                   |       P2 |
| SET-169 | Settings should allow admins to manage project-level members and roles where project permissions exist. |       P3 |
| SET-170 | Settings should allow project defaults for sharing, theme, and collaboration where supported.           |       P3 |
| SET-171 | Project deletion shall warn about diagrams, presentations, links, and collaborators affected.           |       P1 |

## 21. Billing and Plan Settings

Mermaid’s pricing page currently lists Basic, Plus, Premium, and Enterprise plans with limits around diagrams, diagram size, AI credits, collaboration, external sharing, SSO, custom contracts/invoicing, customer success, and secure diagram ownership management. ([Mermaid][3])

| ID      | Requirement                                                                                 | Priority |
| ------- | ------------------------------------------------------------------------------------------- | -------: |
| SET-172 | Settings shall show the current plan.                                                       |       P1 |
| SET-173 | Settings shall show diagram usage limits where applicable.                                  |       P1 |
| SET-174 | Settings shall show diagram size limits where applicable.                                   |       P1 |
| SET-175 | Settings shall show AI credit usage where applicable.                                       |       P1 |
| SET-176 | Settings should show available plan features.                                               |       P2 |
| SET-177 | Settings should allow eligible users to upgrade plan.                                       |       P2 |
| SET-178 | Settings should allow eligible users to manage billing cadence where supported.             |       P2 |
| SET-179 | Settings should allow billing admins to view invoices or receipts.                          |       P2 |
| SET-180 | Settings should support centralized billing for teams where applicable.                     |       P2 |
| SET-181 | Settings should support custom contract and invoicing information for Enterprise customers. |       P2 |
| SET-182 | Settings should expose customer success/support contact information for eligible plans.     |       P3 |
| SET-183 | Billing settings shall distinguish plan limits from permission restrictions.                |       P1 |

## 22. Security Settings

Mermaid’s product pages reference secure access controls, custom encryption, SOC2 compliance, and SSO integration; pricing identifies SSO and Enterprise ownership controls as plan-gated features. ([Mermaid][4])

| ID      | Requirement                                                                                                                          | Priority |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------ | -------: |
| SET-184 | Settings shall expose security controls appropriate to the user’s role and plan.                                                     |       P1 |
| SET-185 | Users should be able to manage password or authentication settings where native authentication is used.                              |       P2 |
| SET-186 | Users should be able to manage active sessions where supported.                                                                      |       P2 |
| SET-187 | Users should be able to revoke sessions or sign out of all devices where supported.                                                  |       P3 |
| SET-188 | Workspace admins should be able to configure SSO where supported.                                                                    |       P2 |
| SET-189 | Workspace admins should be able to enforce SSO where supported.                                                                      |       P2 |
| SET-190 | Workspace admins should be able to manage domain-based access rules where supported.                                                 |       P3 |
| SET-191 | Workspace admins should be able to configure external sharing policy.                                                                |       P1 |
| SET-192 | Workspace admins should be able to configure ownership transfer or secure diagram ownership management where Enterprise supports it. |       P2 |
| SET-193 | Security settings should link to compliance documentation where available.                                                           |       P2 |
| SET-194 | Security settings should clearly identify features unavailable on the current plan.                                                  |       P1 |

## 23. Privacy and Data Settings

| ID      | Requirement                                                                                      | Priority |
| ------- | ------------------------------------------------------------------------------------------------ | -------: |
| SET-195 | Settings shall disclose how diagram content is stored and processed at a high level.             |       P1 |
| SET-196 | Settings should disclose how AI prompts are processed.                                           |       P1 |
| SET-197 | Settings should disclose whether diagrams are private by default.                                |       P1 |
| SET-198 | Settings should allow users to export their personal data where policy requires.                 |       P2 |
| SET-199 | Settings should allow users to request deletion of personal data where policy requires.          |       P2 |
| SET-200 | Workspace admins should be able to configure data retention policies where supported.            |       P3 |
| SET-201 | Workspace admins should be able to configure AI retention policies where supported.              |       P3 |
| SET-202 | Settings should distinguish account deletion, workspace removal, and diagram ownership transfer. |       P1 |

## 24. Integrations and Plugins Settings

Mermaid’s product and ecosystem pages reference integrations/plugins including GitHub Copilot, Confluence, Jira, Visual Studio Code, JetBrains IDE, Google Docs, Microsoft PowerPoint, and Word. ([Mermaid][4])

| ID      | Requirement                                                                                            | Priority |
| ------- | ------------------------------------------------------------------------------------------------------ | -------: |
| SET-203 | Settings should provide an Integrations section.                                                       |       P2 |
| SET-204 | Users should be able to view available integrations/plugins.                                           |       P2 |
| SET-205 | Users should be able to connect supported integrations where authentication is required.               |       P2 |
| SET-206 | Users should be able to disconnect integrations.                                                       |       P2 |
| SET-207 | Settings should show integration connection status.                                                    |       P2 |
| SET-208 | Settings should show integration permissions/scopes before connection.                                 |       P1 |
| SET-209 | Settings should support plugin-specific configuration where applicable.                                |       P3 |
| SET-210 | Workspace admins should be able to allow or block integrations for their organization where supported. |       P3 |
| SET-211 | Settings should distinguish first-party integrations from community or third-party integrations.       |       P2 |

## 25. API / Developer Settings

| ID      | Requirement                                                                                          | Priority |
| ------- | ---------------------------------------------------------------------------------------------------- | -------: |
| SET-212 | Settings should provide developer/API settings where the product exposes API or plugin capabilities. |       P3 |
| SET-213 | Users should be able to create API keys or tokens where supported.                                   |       P3 |
| SET-214 | Users should be able to revoke API keys or tokens.                                                   |       P3 |
| SET-215 | Settings should show last-used time for API keys where supported.                                    |       P3 |
| SET-216 | API keys shall only be shown once at creation time.                                                  |       P1 |
| SET-217 | Workspace admins should be able to disable API access where supported.                               |       P3 |
| SET-218 | API settings should warn users not to expose tokens in source code or diagrams.                      |       P1 |

## 26. Accessibility Settings

Mermaid’s open-source docs describe accessibility support including automatically inserted ARIA role descriptions and optional accessible title and description metadata in diagram text. ([Mermaid][5])

| ID      | Requirement                                                                                                     | Priority |
| ------- | --------------------------------------------------------------------------------------------------------------- | -------: |
| SET-219 | Settings should support accessibility preferences.                                                              |       P2 |
| SET-220 | Users should be able to enable reduced motion where animations or transitions exist.                            |       P2 |
| SET-221 | Users should be able to increase editor font size.                                                              |       P2 |
| SET-222 | Users should be able to choose higher-contrast UI appearance where supported.                                   |       P3 |
| SET-223 | Settings should encourage accessible diagram titles and descriptions.                                           |       P2 |
| SET-224 | Settings should allow users to enable accessibility reminders for diagrams missing titles or descriptions.      |       P3 |
| SET-225 | Accessibility settings shall not replace system accessibility settings but should respect them where available. |       P1 |

## 27. Advanced Rendering / Security Configuration

Mermaid’s open-source configuration includes security-related controls such as `securityLevel`, with values including strict, antiscript, loose, and sandbox; the docs describe `strict` as encoding HTML tags and disabling click functionality, while looser modes allow more HTML/click behavior. ([Mermaid][6])

| ID      | Requirement                                                                                                                   | Priority |
| ------- | ----------------------------------------------------------------------------------------------------------------------------- | -------: |
| SET-226 | Advanced settings should expose rendering security options only to users who understand the risk.                             |       P3 |
| SET-227 | Advanced settings should default to safe rendering behavior.                                                                  |       P1 |
| SET-228 | Advanced settings should explain the security implications of allowing HTML, links, scripts, or interactive diagram behavior. |       P1 |
| SET-229 | Workspace admins should be able to restrict unsafe rendering configuration where enterprise policy requires.                  |       P2 |
| SET-230 | Advanced settings should prevent diagram-level config from overriding organization-secured rendering keys where applicable.   |       P2 |
| SET-231 | Settings should expose maximum diagram size or edge-count limits where relevant to performance/security.                      |       P3 |
| SET-232 | Advanced settings should include a reset-to-safe-defaults action.                                                             |       P1 |

## 28. Import Settings

| ID      | Requirement                                                                                      | Priority |
| ------- | ------------------------------------------------------------------------------------------------ | -------: |
| SET-233 | Settings should allow users to configure import preferences.                                     |       P3 |
| SET-234 | Users should be able to choose whether imported Mermaid source is automatically formatted.       |       P3 |
| SET-235 | Users should be able to choose a default folder/project for imported diagrams.                   |       P3 |
| SET-236 | Users should be able to choose whether imported files open immediately after import.             |       P3 |
| SET-237 | Import settings should preserve source where possible and warn before destructive normalization. |       P1 |

## 29. Account Transfer and Ownership Settings

| ID      | Requirement                                                                                             | Priority |
| ------- | ------------------------------------------------------------------------------------------------------- | -------: |
| SET-238 | Settings should support ownership transfer for diagrams where permitted.                                |       P2 |
| SET-239 | Enterprise admins should be able to manage secure diagram ownership transfer where plan supports it.    |       P2 |
| SET-240 | Settings should warn when ownership transfer affects sharing, billing, privacy, or edit permissions.    |       P1 |
| SET-241 | Settings should provide a workflow for transferring diagrams from an individual account to a workspace. |       P2 |
| SET-242 | Settings should provide recovery options when a collaborator leaves the workspace.                      |       P2 |

## 30. Support and Help Settings

| ID      | Requirement                                                                          | Priority |
| ------- | ------------------------------------------------------------------------------------ | -------: |
| SET-243 | Settings should provide access to documentation.                                     |       P1 |
| SET-244 | Settings should provide access to contact support.                                   |       P2 |
| SET-245 | Settings should show current app/product version where relevant.                     |       P2 |
| SET-246 | Settings should show plan-specific support options.                                  |       P2 |
| SET-247 | Settings should show customer success contact information for eligible plans.        |       P3 |
| SET-248 | Settings should provide links to privacy, terms, security, and compliance documents. |       P2 |

## 31. Settings Save, Reset, and Validation Behavior

| ID      | Requirement                                                                         | Priority |
| ------- | ----------------------------------------------------------------------------------- | -------: |
| SET-249 | Settings shall validate inputs before saving.                                       |       P1 |
| SET-250 | Settings shall show success confirmation after saving changes.                      |       P1 |
| SET-251 | Settings shall show clear error messages when changes fail.                         |       P1 |
| SET-252 | Settings shall prevent unauthorized users from saving admin-only settings.          |       P1 |
| SET-253 | Settings should support reset-to-defaults for preference-heavy sections.            |       P2 |
| SET-254 | Settings should require confirmation for destructive or security-sensitive changes. |       P1 |
| SET-255 | Settings should show pending/processing state during save operations.               |       P1 |
| SET-256 | Settings should preserve unsaved changes after recoverable network errors.          |       P2 |

## 32. Settings Empty, Disabled, and Gated States

| ID      | Requirement                                                                                       | Priority |
| ------- | ------------------------------------------------------------------------------------------------- | -------: |
| SET-257 | Settings shall show disabled states for unavailable controls.                                     |       P1 |
| SET-258 | Disabled controls shall explain why they are disabled.                                            |       P1 |
| SET-259 | Settings should distinguish “not available on this plan” from “not allowed by your role.”         |       P1 |
| SET-260 | Settings should distinguish “not supported for this diagram type” from “temporarily unavailable.” |       P2 |
| SET-261 | Settings should provide upgrade messaging for plan-gated features.                                |       P2 |
| SET-262 | Settings should provide contact-admin messaging for role-gated features.                          |       P2 |

## 33. Audit and Change History for Settings

| ID      | Requirement                                                                                | Priority |
| ------- | ------------------------------------------------------------------------------------------ | -------: |
| SET-263 | Security-sensitive settings changes should be logged.                                      |       P2 |
| SET-264 | Workspace setting changes should be visible in an admin audit log where available.         |       P2 |
| SET-265 | Billing and plan changes should be logged for billing admins.                              |       P2 |
| SET-266 | Sharing policy changes should be logged.                                                   |       P2 |
| SET-267 | SSO configuration changes should be logged.                                                |       P2 |
| SET-268 | AI policy changes should be logged.                                                        |       P2 |
| SET-269 | Settings should show who changed admin settings and when where audit logging is available. |       P3 |

## 34. Recommended MVP Scope

| Area             | MVP Requirement                                            |
| ---------------- | ---------------------------------------------------------- |
| Account          | Profile, email display, sign out                           |
| Appearance       | Light, dark, system                                        |
| Editor           | Autosync, pan/zoom, default editor layout                  |
| Diagram defaults | Default diagram theme                                      |
| Sharing          | Default privacy, link sharing, revoke links                |
| AI               | AI enabled state, credits/usage, privacy disclosure        |
| Export           | Default export format: PNG, SVG, MMD                       |
| Library          | Default view and sort                                      |
| Billing          | Current plan, usage limits, upgrade entry point            |
| Workspace        | Members, roles, invite/remove for admins                   |
| Security         | External sharing policy and SSO visibility where available |
| Error states     | Save success, save failure, permission denied              |
| Accessibility    | Keyboard access, reduced motion, readable form labels      |

## 35. Recommended Advanced Scope

| Area               | Advanced Requirement                                              |
| ------------------ | ----------------------------------------------------------------- |
| Admin controls     | Workspace policies, external sharing restrictions, role templates |
| Enterprise         | SSO enforcement, secure ownership transfer, custom contracts      |
| AI governance      | Admin AI enablement, usage reporting, retention controls          |
| Integrations       | Plugin marketplace, connect/disconnect, org allowlist             |
| Audit              | Settings change history and exportable audit logs                 |
| Revision policy    | Local timeline retention and clear-history controls               |
| Advanced rendering | Security level, safe defaults, secured config keys                |
| Accessibility      | Diagram accessibility reminders and contrast preferences          |
| Billing            | Invoices, centralized billing, usage reports                      |
| Data privacy       | Export/delete data, retention policies                            |

## 36. Key Product Caveat

Settings should not become one giant preferences drawer. It should be organized by **scope of consequence**:

```text
Personal preference
→ affects only me

Diagram/editor default
→ affects new work I create

Workspace policy
→ affects team behavior

Security/admin control
→ affects access, compliance, ownership, or data risk

Billing/plan setting
→ affects entitlement, cost, and limits
```

The most important design rule: **every setting should answer “who does this affect?” before the user changes it.**

[1]: https://mermaid.ai/docs/guides/intro?utm_source=chatgpt.com "Mermaid Chart - Create complex, visual diagrams with text. A smarter way of creating diagrams."
[2]: https://mermaid.ai/docs/guides/whiteboard?utm_source=chatgpt.com "Mermaid Chart - Create complex, visual diagrams with text. A smarter way of creating diagrams."
[3]: https://mermaid.ai/web/pricing/?utm_source=chatgpt.com "Mermaid Chart"
[4]: https://mermaid.ai/?utm_source=chatgpt.com "Mermaid Chart"
[5]: https://mermaid.ai/open-source/config/accessibility.html?utm_source=chatgpt.com "Accessibility Options | Mermaid"
[6]: https://mermaid.ai/open-source/config/usage.html?utm_source=chatgpt.com "Usage | Mermaid"
