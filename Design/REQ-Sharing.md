# Mermaid Sharing and Collaboration Requirements

## 1. Core Sharing Scope

| ID     | Requirement                                                                                                                   | Priority |
| ------ | ----------------------------------------------------------------------------------------------------------------------------- | -------: |
| SC-001 | The product shall allow users to share diagrams with other people.                                                            |       P1 |
| SC-002 | The product shall support sharing from the diagram editor.                                                                    |       P1 |
| SC-003 | The product shall support sharing from the Whiteboard or visual editing surface where available.                              |       P1 |
| SC-004 | The product should support sharing from the Library/dashboard.                                                                |       P2 |
| SC-005 | The product should support sharing presentations/decks separately from individual diagrams.                                   |       P2 |
| SC-006 | Sharing shall respect the current user’s role, workspace policy, and subscription plan.                                       |       P1 |
| SC-007 | Sharing shall distinguish between private diagrams, shared diagrams, team/workspace diagrams, and externally shared diagrams. |       P1 |
| SC-008 | Sharing shall not expose diagram source, comments, or metadata to unauthorized users.                                         |       P1 |

## 2. Share Dialog / Share Sheet

| ID     | Requirement                                                                            | Priority |
| ------ | -------------------------------------------------------------------------------------- | -------: |
| SC-009 | The product shall provide a Share button or Share action for each diagram.             |       P1 |
| SC-010 | The Share dialog shall show the current diagram access state.                          |       P1 |
| SC-011 | The Share dialog shall allow permitted users to change diagram access.                 |       P1 |
| SC-012 | The Share dialog shall allow permitted users to invite collaborators by email.         |       P1 |
| SC-013 | The Share dialog shall allow permitted users to create or copy an Editor link.         |       P1 |
| SC-014 | The Share dialog shall allow permitted users to create or copy an SVG link.            |       P1 |
| SC-015 | The Share dialog shall show who currently has access.                                  |       P1 |
| SC-016 | The Share dialog shall show each collaborator’s role or permission level.              |       P1 |
| SC-017 | The Share dialog should show whether external sharing is allowed or blocked.           |       P2 |
| SC-018 | The Share dialog should show plan-gated collaboration features with upgrade messaging. |       P2 |
| SC-019 | The Share dialog should distinguish role restrictions from subscription restrictions.  |       P1 |
| SC-020 | The Share dialog should include a clear revoke/remove access action.                   |       P1 |

## 3. Access Levels and Roles

| ID     | Requirement                                                                                                     | Priority |
| ------ | --------------------------------------------------------------------------------------------------------------- | -------: |
| SC-021 | The product shall support an Owner role.                                                                        |       P1 |
| SC-022 | The product shall support an Editor role where co-editing is available.                                         |       P1 |
| SC-023 | The product shall support a Commenter role where commenting is available.                                       |       P1 |
| SC-024 | The product shall support a Viewer role.                                                                        |       P1 |
| SC-025 | The product shall clearly explain what each role can do.                                                        |       P1 |
| SC-026 | Owners shall be able to rename, edit, share, export, and delete diagrams unless restricted by workspace policy. |       P1 |
| SC-027 | Editors shall be able to edit diagram content where co-editing is available.                                    |       P1 |
| SC-028 | Commenters shall be able to view and comment but not modify diagram source.                                     |       P1 |
| SC-029 | Viewers shall be able to view diagrams but not edit or comment unless explicitly allowed.                       |       P1 |
| SC-030 | The product should support role inheritance from workspace, project, or folder membership.                      |       P2 |
| SC-031 | The product should support diagram-specific permission overrides where policy allows.                           |       P2 |
| SC-032 | The product shall prevent users from assigning roles higher than their own authority permits.                   |       P1 |

## 4. Diagram Access Settings

| ID     | Requirement                                                                                                | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------- | -------: |
| SC-033 | Users with permission shall be able to set a diagram to private.                                           |       P1 |
| SC-034 | Users with permission shall be able to share a diagram with specific users.                                |       P1 |
| SC-035 | Users with permission should be able to share a diagram with a project or workspace.                       |       P2 |
| SC-036 | Users with permission should be able to enable link-based access.                                          |       P2 |
| SC-037 | The product shall show whether a diagram is private, shared, workspace-visible, or public-link-accessible. |       P1 |
| SC-038 | The product shall show when access is restricted by an administrator policy.                               |       P1 |
| SC-039 | The product should allow owners/admins to disable all sharing for a diagram.                               |       P2 |
| SC-040 | The product should allow owners/admins to reset sharing to private.                                        |       P2 |

## 5. Editor Link Sharing

Mermaid’s Editor docs describe sharing with diagram access settings, an Editor link, and an SVG link. ([Mermaid][1])

| ID     | Requirement                                                                                             | Priority |
| ------ | ------------------------------------------------------------------------------------------------------- | -------: |
| SC-041 | The product shall support sharing an Editor link where the plan and policy allow it.                    |       P1 |
| SC-042 | Editor links shall open the diagram in an editable or viewable editor context depending on permissions. |       P1 |
| SC-043 | Editor links shall respect the viewer’s role.                                                           |       P1 |
| SC-044 | Editor links shall not grant edit access unless the recipient has edit permission.                      |       P1 |
| SC-045 | The product shall allow permitted users to copy the Editor link.                                        |       P1 |
| SC-046 | The product should allow permitted users to revoke or regenerate Editor links.                          |       P2 |
| SC-047 | The product should show when an Editor link is active.                                                  |       P2 |
| SC-048 | The product should warn users when creating an externally accessible Editor link.                       |       P2 |
| SC-049 | Editor links should preserve diagram context, including selected mode where appropriate.                |       P3 |
| SC-050 | Editor links should fail gracefully when the diagram is deleted or access is revoked.                   |       P1 |

## 6. SVG Link Sharing

| ID     | Requirement                                                                       | Priority |
| ------ | --------------------------------------------------------------------------------- | -------: |
| SC-051 | The product shall support sharing an SVG link where the plan and policy allow it. |       P1 |
| SC-052 | SVG links shall render the diagram as a visual artifact.                          |       P1 |
| SC-053 | SVG links shall not expose editable source unless explicitly intended.            |       P1 |
| SC-054 | SVG links should update when the source diagram changes if the link is live.      |       P2 |
| SC-055 | The product shall communicate whether an SVG link is live or snapshot-based.      |       P1 |
| SC-056 | The product shall allow permitted users to copy the SVG link.                     |       P1 |
| SC-057 | The product should allow permitted users to revoke or regenerate SVG links.       |       P2 |
| SC-058 | SVG links should respect private diagram access rules.                            |       P1 |
| SC-059 | SVG links should include safe fallback behavior when the diagram cannot render.   |       P1 |
| SC-060 | SVG links should preserve the chosen diagram theme and styling.                   |       P2 |

## 7. Email Invitations

Mermaid’s Whiteboard guide describes inviting collaborators by email and setting diagram permissions from the Share action. ([Mermaid][2])

| ID     | Requirement                                                                        | Priority |
| ------ | ---------------------------------------------------------------------------------- | -------: |
| SC-061 | The product shall allow permitted users to invite collaborators by email.          |       P1 |
| SC-062 | Email invitations shall include the diagram title.                                 |       P1 |
| SC-063 | Email invitations shall include a secure link to the shared diagram.               |       P1 |
| SC-064 | The inviter shall choose the recipient’s role before sending the invite.           |       P1 |
| SC-065 | The product shall validate email addresses before sending invitations.             |       P1 |
| SC-066 | The product should support inviting multiple recipients at once.                   |       P2 |
| SC-067 | The product should show pending invitations.                                       |       P2 |
| SC-068 | The product should allow permitted users to cancel pending invitations.            |       P2 |
| SC-069 | The product should show invite acceptance state where available.                   |       P3 |
| SC-070 | The product should prevent invites that violate workspace external sharing policy. |       P1 |

## 8. View and Comment Collaboration

Mermaid’s pricing page currently lists **View & comment collaboration** as part of the Plus plan. ([Mermaid][3])

| ID     | Requirement                                                               | Priority |
| ------ | ------------------------------------------------------------------------- | -------: |
| SC-071 | The product shall support view-only collaboration.                        |       P1 |
| SC-072 | The product shall support comment collaboration where the plan allows it. |       P1 |
| SC-073 | Commenters shall be able to add comments without editing diagram source.  |       P1 |
| SC-074 | Viewers shall not be able to comment unless granted commenter access.     |       P1 |
| SC-075 | The product shall show when a user has view-only access.                  |       P1 |
| SC-076 | The product shall show when a user has comment access.                    |       P1 |
| SC-077 | The product should allow owners/editors to promote a viewer to commenter. |       P2 |
| SC-078 | The product should allow owners/editors to demote a commenter to viewer.  |       P2 |
| SC-079 | The product should allow users to request edit or comment access.         |       P3 |
| SC-080 | The product should allow owners to approve or deny access requests.       |       P3 |

## 9. Co-Editing Collaboration

Mermaid’s pricing page currently identifies **co-editing collaboration and external sharing** as Premium features; Mermaid’s ecosystem page also describes real-time multi-user editing on paid plans. ([Mermaid][3])

| ID     | Requirement                                                                           | Priority |
| ------ | ------------------------------------------------------------------------------------- | -------: |
| SC-081 | The product shall support co-editing where the plan allows it.                        |       P1 |
| SC-082 | Co-editing shall allow multiple editors to work on the same diagram.                  |       P1 |
| SC-083 | Co-editing shall preserve diagram source integrity during simultaneous edits.         |       P1 |
| SC-084 | Co-editing should show collaborator presence.                                         |       P2 |
| SC-085 | Co-editing should show who is currently editing.                                      |       P2 |
| SC-086 | Co-editing should distinguish active collaborators from passive viewers.              |       P2 |
| SC-087 | Co-editing should avoid overwriting another user’s changes without warning.           |       P1 |
| SC-088 | Co-editing should integrate with undo/redo in a predictable way.                      |       P2 |
| SC-089 | Co-editing should record meaningful collaborative edits in Activity Feed or Timeline. |       P2 |
| SC-090 | Co-editing should gracefully handle conflicting source edits.                         |       P1 |
| SC-091 | Co-editing should gracefully handle reconnect after network loss.                     |       P2 |
| SC-092 | Co-editing should fall back to read-only mode when the user loses edit permission.    |       P1 |

## 10. Comments

Mermaid’s Whiteboard guide describes comments as available in both Editor and Whiteboard. ([Mermaid][2])

| ID     | Requirement                                                                          | Priority |
| ------ | ------------------------------------------------------------------------------------ | -------: |
| SC-093 | The product shall support comments on diagrams where collaboration is available.     |       P1 |
| SC-094 | Comments shall be viewable in the Editor.                                            |       P1 |
| SC-095 | Comments shall be viewable in the Whiteboard where available.                        |       P1 |
| SC-096 | Users with comment permission shall be able to add comments.                         |       P1 |
| SC-097 | Users should be able to reply to comments.                                           |       P2 |
| SC-098 | Users should be able to resolve comments.                                            |       P2 |
| SC-099 | Users should be able to reopen resolved comments.                                    |       P2 |
| SC-100 | Users should be able to edit their own comments.                                     |       P2 |
| SC-101 | Users should be able to delete their own comments.                                   |       P2 |
| SC-102 | Owners/admins should be able to moderate comments where policy allows.               |       P3 |
| SC-103 | Comments should support timestamps.                                                  |       P1 |
| SC-104 | Comments should show author identity.                                                |       P1 |
| SC-105 | Comments should support jump-to-context behavior when attached to a diagram element. |       P2 |
| SC-106 | Comments should preserve permissions when diagrams are shared externally.            |       P1 |

## 11. Anchored Comments

| ID     | Requirement                                                                                                      | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------------- | -------: |
| SC-107 | The product should support comments attached to the overall diagram.                                             |       P2 |
| SC-108 | The product should support comments attached to specific nodes where the editor surface supports it.             |       P2 |
| SC-109 | The product should support comments attached to specific edges where the editor surface supports it.             |       P3 |
| SC-110 | The product should support comments attached to presentation slides where presentations are available.           |       P3 |
| SC-111 | Anchored comments should remain attached after reasonable diagram edits.                                         |       P2 |
| SC-112 | If a commented element is deleted, the product should preserve the comment thread with a deleted-context marker. |       P2 |
| SC-113 | The product should distinguish diagram-level comments from element-level comments.                               |       P2 |

## 12. Mentions and Notifications

| ID     | Requirement                                                                                              | Priority |
| ------ | -------------------------------------------------------------------------------------------------------- | -------: |
| SC-114 | Comments should support @mentions.                                                                       |       P2 |
| SC-115 | Mentioned users should receive a notification where notifications are enabled.                           |       P2 |
| SC-116 | The product should prevent mentioning users who do not have access unless the commenter can invite them. |       P1 |
| SC-117 | The product should offer to grant access when a mentioned user lacks access.                             |       P2 |
| SC-118 | Notifications should include enough context to identify the diagram and comment.                         |       P2 |
| SC-119 | Notifications should not expose private diagram content to unauthorized recipients.                      |       P1 |
| SC-120 | Users should be able to configure comment and mention notification preferences.                          |       P2 |

## 13. External Sharing

Mermaid’s pricing page currently lists **external sharing** with Premium co-editing collaboration. ([Mermaid][3])

| ID     | Requirement                                                                        | Priority |
| ------ | ---------------------------------------------------------------------------------- | -------: |
| SC-121 | The product shall support external sharing where the plan allows it.               |       P1 |
| SC-122 | External sharing shall be distinguishable from internal workspace sharing.         |       P1 |
| SC-123 | The product shall warn users when sharing outside the workspace or organization.   |       P1 |
| SC-124 | Workspace admins shall be able to disable external sharing where supported.        |       P1 |
| SC-125 | Workspace admins should be able to restrict external sharing to approved domains.  |       P2 |
| SC-126 | Workspace admins should be able to require sign-in for external viewers.           |       P2 |
| SC-127 | The Share dialog should display an “External” indicator for outside collaborators. |       P2 |
| SC-128 | The Library should display externally shared status for diagrams.                  |       P2 |
| SC-129 | External users should receive only the minimum access required.                    |       P1 |
| SC-130 | External access should be revocable by owners/admins.                              |       P1 |

## 14. Public, Private, and Workspace Visibility

| ID     | Requirement                                                                                                | Priority |
| ------ | ---------------------------------------------------------------------------------------------------------- | -------: |
| SC-131 | Diagrams shall be private by default unless workspace policy says otherwise.                               |       P1 |
| SC-132 | The product shall support private diagrams visible only to the owner and explicitly invited collaborators. |       P1 |
| SC-133 | The product should support workspace-visible diagrams where team libraries are available.                  |       P2 |
| SC-134 | The product should support project-visible diagrams where project organization is available.               |       P2 |
| SC-135 | The product should support link-accessible diagrams where permitted.                                       |       P2 |
| SC-136 | The product shall clearly label the current visibility state.                                              |       P1 |
| SC-137 | The product shall prevent accidental public/external exposure.                                             |       P1 |
| SC-138 | The product should require confirmation before broadening access.                                          |       P2 |
| SC-139 | The product should not require confirmation when narrowing access unless collaborators will lose access.   |       P3 |

## 15. Team and Workspace Collaboration

Mermaid’s pricing page describes team/project creation and unlimited viewer seats on Premium and above. ([Mermaid][3])

| ID     | Requirement                                                                                  | Priority |
| ------ | -------------------------------------------------------------------------------------------- | -------: |
| SC-140 | The product should support workspace-level collaboration.                                    |       P2 |
| SC-141 | The product should support team and project creation where the plan allows it.               |       P2 |
| SC-142 | The product should allow diagrams to belong to a workspace or project.                       |       P2 |
| SC-143 | Workspace members should be able to discover diagrams they have access to.                   |       P1 |
| SC-144 | Workspace admins should be able to manage members.                                           |       P1 |
| SC-145 | Workspace admins should be able to assign member roles.                                      |       P1 |
| SC-146 | Workspace admins should be able to manage viewer seats where the plan includes viewer seats. |       P2 |
| SC-147 | Workspace admins should be able to see externally shared diagrams.                           |       P2 |
| SC-148 | Workspace admins should be able to remove access for users who leave the workspace.          |       P1 |
| SC-149 | Workspace admins should be able to transfer ownership where supported.                       |       P2 |

## 16. Unlimited Viewer Seats

| ID     | Requirement                                                                                            | Priority |
| ------ | ------------------------------------------------------------------------------------------------------ | -------: |
| SC-150 | The product should support viewer-only access without consuming editor seats where the plan allows it. |       P2 |
| SC-151 | Viewer seats shall not grant edit or comment privileges by default.                                    |       P1 |
| SC-152 | The product shall distinguish paid editors from free viewers where billing depends on seat type.       |       P1 |
| SC-153 | Admins should be able to promote viewers to editors where seats and permissions allow.                 |       P2 |
| SC-154 | Admins should be able to demote editors to viewers.                                                    |       P2 |
| SC-155 | The product should show when an attempted promotion requires a paid seat or plan upgrade.              |       P2 |

## 17. Secure Diagram Ownership

Mermaid’s pricing page lists Enterprise secure diagram ownership management / IP transfer to admin. ([Mermaid][3])

| ID     | Requirement                                                                                     | Priority |
| ------ | ----------------------------------------------------------------------------------------------- | -------: |
| SC-156 | The product should support ownership transfer for diagrams where policy allows it.              |       P2 |
| SC-157 | Enterprise admins should be able to manage secure diagram ownership where the plan supports it. |       P2 |
| SC-158 | Ownership transfer shall preserve revision history unless policy requires otherwise.            |       P1 |
| SC-159 | Ownership transfer shall preserve sharing state unless the user/admin changes it.               |       P2 |
| SC-160 | Ownership transfer shall create an audit/activity event.                                        |       P1 |
| SC-161 | The product should support transferring diagrams from a departing user to a workspace admin.    |       P2 |
| SC-162 | The product should warn when ownership transfer affects permissions, billing, or access.        |       P1 |

## 18. SSO and Secure Access

Mermaid’s pricing page lists SSO on higher-tier plans. ([Mermaid][3])

| ID     | Requirement                                                                                     | Priority |
| ------ | ----------------------------------------------------------------------------------------------- | -------: |
| SC-163 | The product should support SSO for workspace access where the plan allows it.                   |       P2 |
| SC-164 | Workspace admins should be able to require SSO for workspace members.                           |       P2 |
| SC-165 | Workspace admins should be able to restrict sharing to authenticated users.                     |       P2 |
| SC-166 | Workspace admins should be able to block non-SSO users from accessing workspace diagrams.       |       P2 |
| SC-167 | The product should clearly explain when a share recipient must sign in.                         |       P1 |
| SC-168 | The product should provide a clear access-denied state for users who fail SSO or domain checks. |       P1 |
| SC-169 | Sharing links should not bypass SSO enforcement.                                                |       P1 |

## 19. Permission Change Behavior

| ID     | Requirement                                                                                         | Priority |
| ------ | --------------------------------------------------------------------------------------------------- | -------: |
| SC-170 | The product shall allow owners/admins to change a collaborator’s role.                              |       P1 |
| SC-171 | The product shall allow owners/admins to remove a collaborator.                                     |       P1 |
| SC-172 | Role changes shall take effect promptly.                                                            |       P1 |
| SC-173 | Removed collaborators shall lose access promptly.                                                   |       P1 |
| SC-174 | The product should notify affected users when their access changes.                                 |       P2 |
| SC-175 | The product should warn if removing a collaborator may break shared workflows.                      |       P3 |
| SC-176 | The product should prevent the last owner from removing themselves unless ownership is transferred. |       P1 |
| SC-177 | Permission changes shall be logged in Activity Feed or audit history.                               |       P1 |

## 20. Collaboration Across Editing Modes

Mermaid docs describe toggles among Mermaid AI, Editor, and Whiteboard, and Whiteboard comments are viewable in Editor and Whiteboard. ([Mermaid][2])

| ID     | Requirement                                                                                                                 | Priority |
| ------ | --------------------------------------------------------------------------------------------------------------------------- | -------: |
| SC-178 | Collaboration shall work consistently across Code Editor and rendered preview.                                              |       P1 |
| SC-179 | Comments shall be visible across Editor and Whiteboard where supported.                                                     |       P1 |
| SC-180 | Sharing permissions shall apply consistently across Code Editor, Visual Editor, Whiteboard, AI, Library, and Presentations. |       P1 |
| SC-181 | A user without edit permission shall not be able to edit through any mode.                                                  |       P1 |
| SC-182 | A user without comment permission shall not be able to add comments through any mode.                                       |       P1 |
| SC-183 | A user without view permission shall not be able to access the diagram through direct links.                                |       P1 |
| SC-184 | The product should explain when a collaboration feature is unavailable in the current mode.                                 |       P2 |

## 21. Collaboration with AI-Generated Diagrams

| ID     | Requirement                                                                                                   | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------- | -------: |
| SC-185 | AI-generated diagrams shall inherit the sharing state of the workspace or folder where they are saved.        |       P1 |
| SC-186 | Users should be able to share AI-generated diagrams like any other diagram.                                   |       P2 |
| SC-187 | AI prompts should not be visible to collaborators unless policy and permissions allow it.                     |       P1 |
| SC-188 | AI-generated edits should be visible in revision history where history is available.                          |       P2 |
| SC-189 | Collaborators should be able to comment on AI-generated diagrams where comment access is available.           |       P2 |
| SC-190 | Collaborators should be able to refine AI-generated diagrams only if they have edit permission and AI access. |       P2 |
| SC-191 | The product should distinguish “can edit diagram” from “can use AI credits.”                                  |       P1 |

## 22. Collaboration with Presentations

| ID     | Requirement                                                                                                                   | Priority |
| ------ | ----------------------------------------------------------------------------------------------------------------------------- | -------: |
| SC-192 | Users should be able to share presentations where the plan allows it.                                                         |       P2 |
| SC-193 | Presentation sharing shall respect permissions of embedded diagrams.                                                          |       P1 |
| SC-194 | Viewers of a shared presentation shall not automatically gain edit access to embedded diagrams.                               |       P1 |
| SC-195 | Editors of a presentation shall not automatically gain edit access to all embedded source diagrams unless explicitly granted. |       P1 |
| SC-196 | The product should warn when a presentation contains diagrams the recipient cannot access.                                    |       P2 |
| SC-197 | The product should allow owners to share a presentation as a snapshot when live diagram access cannot be granted.             |       P3 |
| SC-198 | Presentation comments should be separate from diagram comments unless explicitly linked.                                      |       P3 |

## 23. Activity Feed and Audit Events

| ID     | Requirement                                                                               | Priority |
| ------ | ----------------------------------------------------------------------------------------- | -------: |
| SC-199 | Sharing and collaboration actions shall create activity events.                           |       P1 |
| SC-200 | The Activity Feed shall log collaborator invitations.                                     |       P1 |
| SC-201 | The Activity Feed shall log collaborator removals.                                        |       P1 |
| SC-202 | The Activity Feed shall log role changes.                                                 |       P1 |
| SC-203 | The Activity Feed shall log share-link creation.                                          |       P1 |
| SC-204 | The Activity Feed shall log share-link revocation.                                        |       P1 |
| SC-205 | The Activity Feed shall log comment creation and resolution.                              |       P1 |
| SC-206 | The Activity Feed should log external sharing events.                                     |       P2 |
| SC-207 | Admin audit logs should include permission, SSO, ownership, and external sharing changes. |       P2 |
| SC-208 | Audit logs should be exportable by admins where enterprise compliance requires it.        |       P3 |

## 24. Collaboration Notifications

| ID     | Requirement                                                                                       | Priority |
| ------ | ------------------------------------------------------------------------------------------------- | -------: |
| SC-209 | The product should notify users when they are invited to a diagram.                               |       P2 |
| SC-210 | The product should notify users when they are mentioned in a comment.                             |       P2 |
| SC-211 | The product should notify owners when a diagram is externally shared if admin policy requires it. |       P3 |
| SC-212 | The product should notify users when their access changes.                                        |       P2 |
| SC-213 | The product should support email notifications.                                                   |       P2 |
| SC-214 | The product should support in-app notifications.                                                  |       P2 |
| SC-215 | Users should be able to configure notification preferences.                                       |       P2 |
| SC-216 | Notifications shall not expose private content to users who lack access.                          |       P1 |

## 25. Link Lifecycle Management

| ID     | Requirement                                                                         | Priority |
| ------ | ----------------------------------------------------------------------------------- | -------: |
| SC-217 | Owners/admins should be able to view active share links.                            |       P2 |
| SC-218 | Owners/admins should be able to revoke active share links.                          |       P1 |
| SC-219 | Owners/admins should be able to regenerate share links.                             |       P2 |
| SC-220 | Share links should have a clear access level.                                       |       P1 |
| SC-221 | Share links should indicate whether they are internal-only or external-accessible.  |       P1 |
| SC-222 | Share links should support expiration where security policy requires it.            |       P3 |
| SC-223 | Share links should support password protection where security policy requires it.   |       P3 |
| SC-224 | Share links should support domain restrictions where enterprise policy requires it. |       P3 |

## 26. Access Requests

| ID     | Requirement                                                                              | Priority |
| ------ | ---------------------------------------------------------------------------------------- | -------: |
| SC-225 | Users who open a restricted diagram link should see an access-denied state.              |       P1 |
| SC-226 | The access-denied state should allow users to request access where supported.            |       P2 |
| SC-227 | Owners/admins should receive access requests.                                            |       P2 |
| SC-228 | Owners/admins should be able to approve or deny access requests.                         |       P2 |
| SC-229 | Access requests should include requested role, requester identity, and optional message. |       P3 |
| SC-230 | Access request approval shall create a permission-change event.                          |       P1 |

## 27. Error and Edge States

| ID     | Requirement                                                                          | Priority |
| ------ | ------------------------------------------------------------------------------------ | -------: |
| SC-231 | The product shall show an error when sharing fails.                                  |       P1 |
| SC-232 | The product shall show an error when an invite cannot be sent.                       |       P1 |
| SC-233 | The product shall show an error when a role change fails.                            |       P1 |
| SC-234 | The product shall show an error when a share link cannot be created.                 |       P1 |
| SC-235 | The product shall show an error when a user lacks permission to share.               |       P1 |
| SC-236 | The product shall show an error when external sharing is blocked by policy.          |       P1 |
| SC-237 | The product shall show an error when the feature is unavailable on the current plan. |       P1 |
| SC-238 | The product should preserve pending share form inputs after recoverable errors.      |       P2 |
| SC-239 | The product should retry failed collaboration sync operations where safe.            |       P2 |
| SC-240 | Deleted users should appear as “Deleted user” or equivalent in comments/activity.    |       P2 |
| SC-241 | Deleted diagrams should show a clear unavailable state when opened from old links.   |       P1 |

## 28. Privacy and Data Protection

| ID     | Requirement                                                                                                   | Priority |
| ------ | ------------------------------------------------------------------------------------------------------------- | -------: |
| SC-242 | Sharing shall preserve diagram privacy by default.                                                            |       P1 |
| SC-243 | Sharing shall not expose private diagram source through thumbnails, previews, SVG links, or notifications.    |       P1 |
| SC-244 | Comments shall be visible only to users with appropriate access.                                              |       P1 |
| SC-245 | AI prompts associated with shared diagrams shall be hidden unless explicitly allowed.                         |       P1 |
| SC-246 | External collaborators shall not see internal workspace membership lists unless permitted.                    |       P1 |
| SC-247 | The product should support administrator policies for external sharing, link sharing, and comment visibility. |       P2 |
| SC-248 | The product should clearly disclose who can see a diagram before sharing changes are applied.                 |       P1 |

## 29. Plan Gating

| ID     | Requirement                                                                             | Priority |
| ------ | --------------------------------------------------------------------------------------- | -------: |
| SC-249 | The product shall gate collaboration features based on subscription plan.               |       P1 |
| SC-250 | The product shall distinguish view/comment collaboration from co-editing collaboration. |       P1 |
| SC-251 | The product shall distinguish internal sharing from external sharing.                   |       P1 |
| SC-252 | The product should show upgrade messaging for co-editing when unavailable.              |       P2 |
| SC-253 | The product should show upgrade messaging for external sharing when unavailable.        |       P2 |
| SC-254 | The product should show upgrade messaging for SSO when unavailable.                     |       P2 |
| SC-255 | The product should show upgrade messaging for unlimited viewer seats when unavailable.  |       P2 |
| SC-256 | The product shall avoid hard-coding plan details that may change over time.             |       P1 |
| SC-257 | The product should fetch entitlements from a configurable source.                       |       P1 |

## 30. Accessibility

| ID     | Requirement                                                      | Priority |
| ------ | ---------------------------------------------------------------- | -------: |
| SC-258 | Share dialogs shall be keyboard accessible.                      |       P1 |
| SC-259 | Role selectors shall be keyboard accessible.                     |       P1 |
| SC-260 | Comment controls shall be keyboard accessible.                   |       P1 |
| SC-261 | Collaborator lists shall expose accessible names and roles.      |       P1 |
| SC-262 | Presence indicators shall not rely on color alone.               |       P1 |
| SC-263 | Sharing status shall not rely on color alone.                    |       P1 |
| SC-264 | Error messages shall be announced to assistive technologies.     |       P1 |
| SC-265 | Permission changes should provide clear confirmation text.       |       P1 |
| SC-266 | Comment threads should be navigable with assistive technologies. |       P2 |

## 31. Performance and Reliability

| ID     | Requirement                                                                                  | Priority |
| ------ | -------------------------------------------------------------------------------------------- | -------: |
| SC-267 | Sharing state shall load quickly when the Share dialog opens.                                |       P1 |
| SC-268 | Collaborator lists should support pagination or search for large teams.                      |       P2 |
| SC-269 | Co-editing should remain responsive under normal multi-user editing conditions.              |       P2 |
| SC-270 | Comment threads should load incrementally for heavily commented diagrams.                    |       P2 |
| SC-271 | The product should not block diagram editing while collaboration metadata loads.             |       P1 |
| SC-272 | The product should reconcile local edits with remote collaboration state after reconnecting. |       P2 |
| SC-273 | The product should preserve user edits during temporary network loss.                        |       P1 |

## 32. Recommended MVP Scope

| Area           | MVP Requirement                                           |
| -------------- | --------------------------------------------------------- |
| Share action   | Share button in Editor and Library                        |
| Access control | Private, invited users, viewer/commenter/editor roles     |
| Invite         | Invite collaborators by email                             |
| Links          | Copy Editor link and SVG link                             |
| Permissions    | Change role, remove collaborator, revoke links            |
| Comments       | Add, reply, resolve, and view comments                    |
| Plan awareness | View/comment vs co-editing vs external sharing            |
| Activity       | Log invites, role changes, link changes, comments         |
| Safety         | Warn before external sharing                              |
| Error states   | Permission denied, plan gated, invite failed, link failed |
| Accessibility  | Keyboard-accessible sharing and comments                  |

## 33. Recommended Advanced Scope

| Area            | Advanced Requirement                                          |
| --------------- | ------------------------------------------------------------- |
| Co-editing      | Real-time collaborative source and visual editing             |
| Presence        | Active collaborator indicators                                |
| Mentions        | @mentions with notifications                                  |
| Access requests | Request/approve access from restricted links                  |
| Admin controls  | External sharing policy, domain restrictions, SSO enforcement |
| Audit           | Exportable admin audit log                                    |
| Ownership       | Enterprise ownership transfer                                 |
| Link management | Expiration, regeneration, revocation, domain restrictions     |
| Workspace scale | Unlimited viewer seats and large collaborator search          |
| Presentations   | Share decks while respecting embedded diagram permissions     |

## 34. Key Product Caveat

Sharing and collaboration should be modeled as **permission-aware document collaboration**, not just “copy a link.”

The ideal flow is:

```text
Diagram
→ choose audience
→ choose permission
→ choose sharing method
→ invite or copy link
→ collaborate through comments / co-editing
→ track activity
→ revoke or adjust access later
```

The most important design rule: **before the user shares, they should know exactly who can see the diagram, who can edit it, whether the link leaves the workspace, and whether the action is allowed by their plan or admin policy.**

[1]: https://mermaid.ai/docs/guides/intro?utm_source=chatgpt.com "Mermaid Chart - Create complex, visual diagrams with text. A smarter way of creating diagrams."
[2]: https://mermaid.ai/docs/guides/whiteboard?utm_source=chatgpt.com "Mermaid Chart - Create complex, visual diagrams with text. A smarter way of creating diagrams."
[3]: https://mermaid.ai/web/pricing/?utm_source=chatgpt.com "Mermaid Chart"
