# Mermaid Activity Feed Requirements

## 1. Core Activity Feed Scope

| ID     | Requirement                                                                                                            | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------- | -------: |
| AF-001 | The product shall provide an Activity Feed for tracking meaningful changes and collaboration events across diagrams.   |       P1 |
| AF-002 | The Activity Feed shall show recent activity for the currently selected diagram.                                       |       P1 |
| AF-003 | The Activity Feed should support workspace-level activity across multiple diagrams.                                    |       P2 |
| AF-004 | The Activity Feed shall show who performed each activity.                                                              |       P1 |
| AF-005 | The Activity Feed shall show when each activity occurred.                                                              |       P1 |
| AF-006 | The Activity Feed shall describe what changed in plain language.                                                       |       P1 |
| AF-007 | The Activity Feed should group related events into readable clusters.                                                  |       P2 |
| AF-008 | The Activity Feed shall distinguish between user actions, AI actions, system actions, and permission/share actions.    |       P1 |
| AF-009 | The Activity Feed should support filtering by activity type.                                                           |       P2 |
| AF-010 | The Activity Feed should support search across activity text, user names, diagram names, comments, and event metadata. |       P2 |

## 2. Feed Placement and Access

| ID     | Requirement                                                                                  | Priority |
| ------ | -------------------------------------------------------------------------------------------- | -------: |
| AF-011 | The Activity Feed shall be accessible from the diagram editor.                               |       P1 |
| AF-012 | The Activity Feed should be available as a side panel, inspector tab, or collapsible drawer. |       P2 |
| AF-013 | The Activity Feed should be accessible from the dashboard/workspace view.                    |       P2 |
| AF-014 | The Activity Feed should be accessible from a diagram’s “More Options” or metadata menu.     |       P2 |
| AF-015 | The Activity Feed should not obscure the main diagram editing surface by default.            |       P1 |
| AF-016 | The Activity Feed should preserve scroll position when temporarily closed and reopened.      |       P2 |
| AF-017 | The Activity Feed should support compact and expanded item layouts.                          |       P2 |

## 3. Diagram Revision Events

| ID     | Requirement                                                                                                        | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------------ | -------: |
| AF-018 | The Activity Feed shall log when a diagram is created.                                                             |       P1 |
| AF-019 | The Activity Feed shall log when a diagram is renamed.                                                             |       P1 |
| AF-020 | The Activity Feed shall log when Mermaid source is edited.                                                         |       P1 |
| AF-021 | The Activity Feed shall log when visual editor changes are made.                                                   |       P1 |
| AF-022 | The Activity Feed shall log when nodes are added, removed, or modified where event detail is available.            |       P2 |
| AF-023 | The Activity Feed shall log when edges/connectors are added, removed, or modified where event detail is available. |       P2 |
| AF-024 | The Activity Feed shall log when theme or styling changes are applied.                                             |       P2 |
| AF-025 | The Activity Feed shall log when diagram layout direction changes.                                                 |       P2 |
| AF-026 | The Activity Feed shall log when diagram code is prettified or normalized by the Visual Editor.                    |       P1 |
| AF-027 | The Activity Feed should show a before/after summary for source changes.                                           |       P2 |
| AF-028 | The Activity Feed should allow users to open a specific revision from an activity item.                            |       P2 |
| AF-029 | The Activity Feed should integrate with local timeline/revision history.                                           |       P1 |
| AF-030 | The Activity Feed should allow reverting to a previous revision where revision history supports restore.           |       P2 |

## 4. Autosave and Timeline Events

| ID     | Requirement                                                                                                                              | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AF-031 | The Activity Feed shall distinguish autosaved edits from explicitly saved/published changes.                                             |       P1 |
| AF-032 | The Activity Feed should avoid creating noisy feed items for every keystroke.                                                            |       P1 |
| AF-033 | Autosaved edits should be batched into meaningful activity groups.                                                                       |       P1 |
| AF-034 | The Activity Feed should show “edited diagram” events after a debounce or session boundary.                                              |       P2 |
| AF-035 | The Activity Feed should support an expandable details view for batched edit sessions.                                                   |       P2 |
| AF-036 | The Activity Feed should identify the editor mode used for an edit, such as Code Editor, Visual Editor, Whiteboard, AI, or Presentation. |       P2 |
| AF-037 | The Activity Feed should indicate whether a change is restorable.                                                                        |       P2 |

## 5. Comment Events

| ID     | Requirement                                                                                                                      | Priority |
| ------ | -------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AF-038 | The Activity Feed shall log when a comment is added.                                                                             |       P1 |
| AF-039 | The Activity Feed shall log when a comment is edited.                                                                            |       P2 |
| AF-040 | The Activity Feed shall log when a comment is deleted.                                                                           |       P2 |
| AF-041 | The Activity Feed shall log when a comment is resolved.                                                                          |       P1 |
| AF-042 | The Activity Feed shall log when a comment is reopened.                                                                          |       P2 |
| AF-043 | The Activity Feed shall log when a user replies to a comment thread.                                                             |       P1 |
| AF-044 | The Activity Feed should show a short preview of comment text.                                                                   |       P2 |
| AF-045 | The Activity Feed should allow users to jump from a feed item to the associated comment.                                         |       P1 |
| AF-046 | The Activity Feed should indicate whether the comment is attached to the diagram, a node, an edge, a slide, or a general thread. |       P2 |
| AF-047 | The Activity Feed should respect comment visibility and permissions.                                                             |       P1 |

## 6. Collaboration Events

| ID     | Requirement                                                                                                              | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------------------ | -------: |
| AF-048 | The Activity Feed shall log when a collaborator is invited.                                                              |       P1 |
| AF-049 | The Activity Feed shall log when a collaborator accepts an invite.                                                       |       P2 |
| AF-050 | The Activity Feed shall log when a collaborator is removed.                                                              |       P1 |
| AF-051 | The Activity Feed shall log when a collaborator’s role or access level changes.                                          |       P1 |
| AF-052 | The Activity Feed should log co-editing sessions at a summary level.                                                     |       P2 |
| AF-053 | The Activity Feed should avoid logging transient presence events unless explicitly enabled.                              |       P2 |
| AF-054 | The Activity Feed should show when someone joins or leaves active collaborative editing only in live collaboration mode. |       P3 |
| AF-055 | The Activity Feed shall respect viewer/editor/commenter permissions.                                                     |       P1 |

## 7. Sharing and Permission Events

| ID     | Requirement                                                                               | Priority |
| ------ | ----------------------------------------------------------------------------------------- | -------: |
| AF-056 | The Activity Feed shall log when diagram sharing is enabled.                              |       P1 |
| AF-057 | The Activity Feed shall log when diagram sharing is disabled.                             |       P1 |
| AF-058 | The Activity Feed shall log when a share link is created.                                 |       P1 |
| AF-059 | The Activity Feed shall log when a share link is revoked.                                 |       P1 |
| AF-060 | The Activity Feed shall log when diagram access level changes.                            |       P1 |
| AF-061 | The Activity Feed should distinguish between Editor links and SVG links.                  |       P2 |
| AF-062 | The Activity Feed should log when external sharing is enabled or disabled.                |       P2 |
| AF-063 | The Activity Feed should log permission-denied access attempts only for admins or owners. |       P3 |
| AF-064 | The Activity Feed shall not expose private share URLs to unauthorized users.              |       P1 |

## 8. Export and Copy Events

| ID     | Requirement                                                                                                 | Priority |
| ------ | ----------------------------------------------------------------------------------------------------------- | -------: |
| AF-065 | The Activity Feed should log when a diagram is exported.                                                    |       P2 |
| AF-066 | The Activity Feed should capture export format, such as PNG, SVG, or MMD.                                   |       P2 |
| AF-067 | The Activity Feed should log when Mermaid source is copied.                                                 |       P3 |
| AF-068 | The Activity Feed should log when a diagram image is copied.                                                |       P3 |
| AF-069 | The Activity Feed should log failed exports where useful for troubleshooting.                               |       P3 |
| AF-070 | Export events should be visible to diagram owners and admins, but may be hidden from regular collaborators. |       P3 |

## 9. AI Activity Events

| ID     | Requirement                                                                                                       | Priority |
| ------ | ----------------------------------------------------------------------------------------------------------------- | -------: |
| AF-071 | The Activity Feed shall log when a diagram is generated by AI.                                                    |       P1 |
| AF-072 | The Activity Feed shall log when AI modifies an existing diagram.                                                 |       P1 |
| AF-073 | The Activity Feed should preserve the prompt associated with an AI-generated change where privacy settings allow. |       P2 |
| AF-074 | The Activity Feed should summarize AI actions in plain language.                                                  |       P2 |
| AF-075 | The Activity Feed should distinguish AI-generated source from manually authored source.                           |       P2 |
| AF-076 | The Activity Feed should log failed AI generation attempts where relevant.                                        |       P2 |
| AF-077 | The Activity Feed should log AI credit or quota exhaustion events only for the affected user and administrators.  |       P2 |
| AF-078 | The Activity Feed should allow users to compare the diagram before and after an AI edit.                          |       P2 |
| AF-079 | The Activity Feed should allow users to restore the previous version after an AI edit.                            |       P2 |
| AF-080 | The Activity Feed shall respect organization-level privacy policies for prompt retention.                         |       P1 |

## 10. Presentation Activity Events

| ID     | Requirement                                                                                                      | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------- | -------: |
| AF-081 | The Activity Feed should log when a presentation is created from a diagram.                                      |       P2 |
| AF-082 | The Activity Feed should log when a diagram is inserted into a presentation.                                     |       P2 |
| AF-083 | The Activity Feed should log when a presentation is edited.                                                      |       P2 |
| AF-084 | The Activity Feed should log when a presentation is shared.                                                      |       P2 |
| AF-085 | The Activity Feed should log when a linked diagram used in a presentation changes.                               |       P2 |
| AF-086 | The Activity Feed should warn when a presentation may contain stale diagram content.                             |       P3 |
| AF-087 | The Activity Feed should allow users to jump from a presentation-related activity to the relevant deck or slide. |       P2 |

## 11. Whiteboard / Visual Editing Events

| ID     | Requirement                                                                                            | Priority |
| ------ | ------------------------------------------------------------------------------------------------------ | -------: |
| AF-088 | The Activity Feed should log when a diagram is edited in Whiteboard mode.                              |       P2 |
| AF-089 | The Activity Feed should log multiple-selection edits as grouped events.                               |       P2 |
| AF-090 | The Activity Feed should log node styling changes made visually.                                       |       P2 |
| AF-091 | The Activity Feed should log edge styling changes made visually.                                       |       P2 |
| AF-092 | The Activity Feed should log fullscreen presentation or whiteboard review sessions only when relevant. |       P3 |
| AF-093 | The Activity Feed should allow users to jump from visual-edit events to the corresponding diagram.     |       P2 |

## 12. Workspace-Level Feed

| ID     | Requirement                                                                                                                     | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AF-094 | The product should provide a workspace-level feed showing activity across diagrams, presentations, comments, and collaborators. |       P2 |
| AF-095 | Workspace feed items shall include the affected diagram or presentation name.                                                   |       P1 |
| AF-096 | Workspace feed items shall include the acting user.                                                                             |       P1 |
| AF-097 | Workspace feed items shall include the activity timestamp.                                                                      |       P1 |
| AF-098 | Workspace feed items should support filtering by diagram.                                                                       |       P2 |
| AF-099 | Workspace feed items should support filtering by user.                                                                          |       P2 |
| AF-100 | Workspace feed items should support filtering by activity category.                                                             |       P2 |
| AF-101 | Workspace feed items should support filtering by date range.                                                                    |       P2 |
| AF-102 | Workspace feed should respect each viewer’s permissions across diagrams and projects.                                           |       P1 |

## 13. Activity Item Content Model

| ID     | Requirement                                                                                                         | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------------- | -------: |
| AF-103 | Each activity item shall include an event type.                                                                     |       P1 |
| AF-104 | Each activity item shall include an actor.                                                                          |       P1 |
| AF-105 | Each activity item shall include a timestamp.                                                                       |       P1 |
| AF-106 | Each activity item shall include a target object, such as diagram, comment, presentation, share link, or workspace. |       P1 |
| AF-107 | Each activity item should include a human-readable summary.                                                         |       P1 |
| AF-108 | Each activity item should include a machine-readable event identifier.                                              |       P2 |
| AF-109 | Each activity item should include metadata for filtering and audit use.                                             |       P2 |
| AF-110 | Each activity item should include a deep link to the affected object when possible.                                 |       P1 |
| AF-111 | Each activity item should include an icon or visual marker for event category.                                      |       P2 |
| AF-112 | Each activity item should expose expandable technical details for admins.                                           |       P3 |

## 14. Feed Grouping and Noise Reduction

| ID     | Requirement                                                                                                                 | Priority |
| ------ | --------------------------------------------------------------------------------------------------------------------------- | -------: |
| AF-113 | The Activity Feed shall group rapid consecutive edits from the same user into a single edit session.                        |       P1 |
| AF-114 | The Activity Feed should group similar events, such as multiple comments resolved in one session.                           |       P2 |
| AF-115 | The Activity Feed should avoid duplicating the same activity across diagram and workspace feeds unless context requires it. |       P2 |
| AF-116 | The Activity Feed should collapse low-value system events by default.                                                       |       P2 |
| AF-117 | The Activity Feed should allow users to expand grouped activity.                                                            |       P2 |
| AF-118 | The Activity Feed should show the most important activity first in collapsed groups.                                        |       P2 |
| AF-119 | The Activity Feed should use relative timestamps for recent items and absolute timestamps in details.                       |       P2 |

## 15. Filters, Search, and Sorting

| ID     | Requirement                                                                                                                      | Priority |
| ------ | -------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AF-120 | The Activity Feed shall support chronological sorting.                                                                           |       P1 |
| AF-121 | The Activity Feed should support newest-first and oldest-first sorting.                                                          |       P2 |
| AF-122 | The Activity Feed should support text search.                                                                                    |       P2 |
| AF-123 | The Activity Feed should support filtering by activity type.                                                                     |       P2 |
| AF-124 | The Activity Feed should support filtering by actor.                                                                             |       P2 |
| AF-125 | The Activity Feed should support filtering by date range.                                                                        |       P2 |
| AF-126 | The Activity Feed should support filtering by source mode, such as Code, Visual Editor, AI, Whiteboard, Presentation, or System. |       P2 |
| AF-127 | The Activity Feed should support filtering unresolved comment activity.                                                          |       P2 |
| AF-128 | The Activity Feed should support filtering permission/share events for owners and admins.                                        |       P2 |

## 16. Notifications and Unread State

| ID     | Requirement                                                                    | Priority |
| ------ | ------------------------------------------------------------------------------ | -------: |
| AF-129 | The product should show unread activity counts for diagrams with new activity. |       P2 |
| AF-130 | The product should mark activity as read when the user views the feed.         |       P2 |
| AF-131 | The product should allow users to mark activity items as unread.               |       P3 |
| AF-132 | The product should notify users when they are mentioned in comments.           |       P2 |
| AF-133 | The product should notify users when a diagram they own is shared externally.  |       P2 |
| AF-134 | The product should notify users when their access changes.                     |       P2 |
| AF-135 | The product should allow users to configure notification preferences.          |       P3 |
| AF-136 | The product should distinguish feed history from active notifications.         |       P1 |

## 17. Mentions and Assignments

| ID     | Requirement                                                                     | Priority |
| ------ | ------------------------------------------------------------------------------- | -------: |
| AF-137 | The Activity Feed should support @mention activity from comments.               |       P2 |
| AF-138 | The Activity Feed should show when a user is mentioned.                         |       P2 |
| AF-139 | The Activity Feed should allow users to jump directly to the mention context.   |       P2 |
| AF-140 | The product should support assigning comment threads or review items to users.  |       P3 |
| AF-141 | The Activity Feed should log assignment creation, reassignment, and completion. |       P3 |
| AF-142 | The Activity Feed should support filtering to “activity involving me.”          |       P2 |

## 18. Version Comparison and Restore

| ID     | Requirement                                                                                                  | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------ | -------: |
| AF-143 | Activity items representing diagram edits should allow users to open the related version.                    |       P2 |
| AF-144 | Activity items should allow comparing the current diagram against a previous version.                        |       P2 |
| AF-145 | The product should show Mermaid source differences for code edits.                                           |       P2 |
| AF-146 | The product should show visual differences for rendered diagram changes where feasible.                      |       P3 |
| AF-147 | The product should support restoring a previous version from activity history where revision history allows. |       P2 |
| AF-148 | Restoring a version shall create a new activity item.                                                        |       P1 |
| AF-149 | The Activity Feed shall not erase the audit trail when a previous version is restored.                       |       P1 |

## 19. Privacy and Permissions

| ID     | Requirement                                                                                               | Priority |
| ------ | --------------------------------------------------------------------------------------------------------- | -------: |
| AF-150 | The Activity Feed shall only show activity the current user is allowed to see.                            |       P1 |
| AF-151 | Private comments shall not appear to unauthorized users.                                                  |       P1 |
| AF-152 | Private diagrams shall not appear in workspace-level feeds for unauthorized users.                        |       P1 |
| AF-153 | Share-link details shall be redacted from users without permission.                                       |       P1 |
| AF-154 | AI prompts shall be hidden or redacted according to workspace privacy settings.                           |       P1 |
| AF-155 | Admins should have access to security-relevant activity where permitted by plan and policy.               |       P2 |
| AF-156 | The Activity Feed should disclose when details are hidden due to permissions.                             |       P2 |
| AF-157 | The Activity Feed should avoid exposing sensitive diagram content in previews unless the user has access. |       P1 |

## 20. Audit Log Mode

| ID     | Requirement                                                                                                                        | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------------------- | -------: |
| AF-158 | The product should support an admin-facing audit log separate from the user-facing Activity Feed.                                  |       P2 |
| AF-159 | Audit logs should include permission changes.                                                                                      |       P2 |
| AF-160 | Audit logs should include external sharing changes.                                                                                |       P2 |
| AF-161 | Audit logs should include collaborator invite/removal events.                                                                      |       P2 |
| AF-162 | Audit logs should include AI usage events where applicable.                                                                        |       P2 |
| AF-163 | Audit logs should include exports where required by enterprise policy.                                                             |       P3 |
| AF-164 | Audit logs should support export by admins.                                                                                        |       P3 |
| AF-165 | Audit logs should have retention controls.                                                                                         |       P3 |
| AF-166 | User-facing Activity Feed should remain readable and collaborative, while audit logs may be more technical and compliance-focused. |       P1 |

## 21. Feed Empty States

| ID     | Requirement                                                                                                | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------- | -------: |
| AF-167 | The Activity Feed shall show an empty state when no activity exists.                                       |       P1 |
| AF-168 | The empty state should explain what kinds of actions will appear in the feed.                              |       P2 |
| AF-169 | The empty state should not imply collaboration activity exists when the user is working alone.             |       P1 |
| AF-170 | Diagram-level empty state should invite the user to edit, comment, share, or generate activity.            |       P2 |
| AF-171 | Workspace-level empty state should explain that activity will appear after diagrams are created or shared. |       P2 |

## 22. Error Handling

| ID     | Requirement                                                                                       | Priority |
| ------ | ------------------------------------------------------------------------------------------------- | -------: |
| AF-172 | The Activity Feed shall show a loading state while fetching activity.                             |       P1 |
| AF-173 | The Activity Feed shall show an error state if activity cannot be loaded.                         |       P1 |
| AF-174 | The Activity Feed shall support retry after a load failure.                                       |       P1 |
| AF-175 | The Activity Feed should preserve already loaded activity if newer activity fails to load.        |       P2 |
| AF-176 | The Activity Feed should show permission errors separately from network errors.                   |       P2 |
| AF-177 | The Activity Feed should handle deleted diagrams, deleted users, and deleted comments gracefully. |       P1 |
| AF-178 | Deleted users should appear as “Deleted user” or equivalent without breaking the feed.            |       P1 |
| AF-179 | Deleted target objects should show that the referenced object is no longer available.             |       P1 |

## 23. Accessibility

| ID     | Requirement                                                                   | Priority |
| ------ | ----------------------------------------------------------------------------- | -------: |
| AF-180 | The Activity Feed shall be keyboard accessible.                               |       P1 |
| AF-181 | Activity items shall be readable by assistive technologies.                   |       P1 |
| AF-182 | Activity category icons shall have accessible labels.                         |       P1 |
| AF-183 | The feed shall not rely on color alone to distinguish activity types.         |       P1 |
| AF-184 | New activity should be announced appropriately when the feed is open.         |       P2 |
| AF-185 | Relative timestamps should expose exact timestamps to assistive technologies. |       P2 |
| AF-186 | Expand/collapse controls shall be accessible.                                 |       P1 |
| AF-187 | Filter controls shall be accessible.                                          |       P1 |

## 24. Performance and Scale

| ID     | Requirement                                                                             | Priority |
| ------ | --------------------------------------------------------------------------------------- | -------: |
| AF-188 | The Activity Feed shall support pagination or incremental loading.                      |       P1 |
| AF-189 | The Activity Feed should load the most recent activity first.                           |       P1 |
| AF-190 | The Activity Feed should support large workspaces without loading all activity at once. |       P1 |
| AF-191 | The Activity Feed should update efficiently when new activity arrives.                  |       P2 |
| AF-192 | The Activity Feed should debounce frequent edit events before writing feed entries.     |       P1 |
| AF-193 | The Activity Feed should avoid blocking diagram editing while activity loads.           |       P1 |
| AF-194 | The Activity Feed should cache recent activity where appropriate.                       |       P2 |

## 25. Real-Time Updates

| ID     | Requirement                                                                                                                  | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------------------- | -------: |
| AF-195 | The Activity Feed should update in near real time during collaborative sessions.                                             |       P2 |
| AF-196 | The Activity Feed should show a “new activity” indicator when new items arrive while the user is scrolled away from the top. |       P2 |
| AF-197 | The Activity Feed should avoid forcing scroll jumps when new activity arrives.                                               |       P1 |
| AF-198 | The Activity Feed should allow users to manually refresh activity.                                                           |       P2 |
| AF-199 | The Activity Feed should reconcile local pending activity with server-confirmed activity.                                    |       P2 |
| AF-200 | The Activity Feed should show pending states for actions that have not yet synced.                                           |       P2 |

## 26. Plan Gating

| ID     | Requirement                                                                                               | Priority |
| ------ | --------------------------------------------------------------------------------------------------------- | -------: |
| AF-201 | Activity Feed availability should respect product plan entitlements.                                      |       P2 |
| AF-202 | Diagram-level activity history should be available even when advanced workspace audit features are gated. |       P2 |
| AF-203 | Admin audit logs may be gated to team, premium, or enterprise plans.                                      |       P2 |
| AF-204 | Collaboration-related activity should only appear where collaboration features are enabled.               |       P1 |
| AF-205 | AI-related activity should only appear where AI features are enabled.                                     |       P1 |
| AF-206 | The product should show clear upgrade messaging for gated activity/audit features.                        |       P2 |

## 27. Recommended MVP Scope

For an MVP Activity Feed, I would include:

| Area           | MVP Requirement                                       |
| -------------- | ----------------------------------------------------- |
| Scope          | Diagram-level activity feed                           |
| Core events    | Created, renamed, edited, restored, shared, commented |
| Timeline       | Integrates with revision history/local timeline       |
| Comments       | Added, replied, resolved                              |
| Sharing        | Share enabled/disabled, access changed                |
| AI             | Diagram generated or modified by AI                   |
| Presentation   | Diagram inserted into presentation                    |
| Feed item      | Actor, timestamp, event type, target, short summary   |
| Navigation     | Jump from activity item to diagram/comment/revision   |
| Privacy        | Respect diagram and comment permissions               |
| Noise control  | Batch frequent edits into edit sessions               |
| Error handling | Loading, empty, failed-to-load, retry                 |
| Accessibility  | Keyboard navigation and accessible labels             |

## 28. Recommended Advanced Scope

After MVP, the most valuable advanced features would be:

| Area                   | Advanced Requirement                             |
| ---------------------- | ------------------------------------------------ |
| Workspace feed         | Cross-diagram activity stream                    |
| Diffing                | Mermaid source diff and visual diff              |
| Restore                | Restore from feed item                           |
| Notifications          | Mentions, unread activity, activity involving me |
| Audit log              | Admin-facing compliance log                      |
| Search                 | Search/filter activity across diagrams           |
| Real time              | Live updates during co-editing                   |
| AI traceability        | Prompt/result history and AI edit comparison     |
| Presentation awareness | Stale diagram detection in decks                 |
| Export tracking        | PNG/SVG/MMD export events for teams              |

## 29. Key Product Caveat

The Activity Feed should not become a noisy keystroke log. It should be a **collaboration and change-awareness layer**.

The best model is:

```text
Every tiny edit
→ grouped into meaningful edit sessions
→ attached to revisions when possible
→ searchable and filterable
→ restorable when appropriate
→ permission-aware everywhere
```

The most important design rule: **make activity useful, not exhaustive.** Users should be able to answer, “What changed, who changed it, why does it matter, and can I get back to the previous state?”

[1]: https://mermaid.ai/docs/guides/intro?utm_source=chatgpt.com "Mermaid Chart - Create complex, visual diagrams with text. A smarter way of creating diagrams."
