import Testing
@testable import BeautifulMermaid

@Suite("TreeView Model")
struct TreeViewModelTests {

    @Test("Synthetic root has correct properties")
    func syntheticRoot() throws {
        let source = "treeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.id == 0)
        #expect(result.root.level == -1)
        #expect(result.root.name == "/")
        #expect(result.root.nodeType == .directory)
        #expect(result.root.iconId == nil)
    }

    @Test("Node ids start at 1 and increment")
    func nodeIdAssignment() throws {
        let source = """
        treeView-beta
            a
            b
            c
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].id == 1)
        #expect(result.root.children[1].id == 2)
        #expect(result.root.children[2].id == 3)
    }

    @Test("Stack pop behavior: deeper then shallower node")
    func stackPopBehavior() throws {
        let source = """
        treeView-beta
            a/
                b/
            c
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children.count == 2)
        #expect(result.root.children[0].name == "a")
        #expect(result.root.children[1].name == "c")
    }

    @Test("Multiple roots have correct parent assignment")
    func multipleRoots() throws {
        let source = """
        treeView-beta
            file1.js
            file2.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children.count == 2)
        #expect(result.root.children[0].name == "file1.js")
        #expect(result.root.children[1].name == "file2.js")
    }

    @Test("Directory normalization removes trailing slash")
    func directoryNormalization() throws {
        let source = """
        treeView-beta
            src/
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].name == "src")
        #expect(result.root.children[0].nodeType == .directory)
    }

    @Test("Directory gets folder icon before filename match")
    func directoryFolderIconPriority() throws {
        let source = """
        treeView-beta
            Dockerfile/
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].iconId == "folder")
    }

    @Test("Known filename gets exact icon match")
    func knownFilenameIcon() throws {
        let icon = resolveIcon(name: "Dockerfile", nodeType: .file)
        #expect(icon == "docker")

        let icon2 = resolveIcon(name: "package.json", nodeType: .file)
        #expect(icon2 == "json")
    }

    @Test("Extension icon case-insensitive")
    func extensionIconCaseInsensitive() throws {
        let icon = resolveIcon(name: "App.TSX", nodeType: .file)
        #expect(icon == "react")

        let icon2 = resolveIcon(name: "file.PY", nodeType: .file)
        #expect(icon2 == "python")
    }

    @Test("Fallback to file icon for unknown extension")
    func fallbackFileIcon() throws {
        let icon = resolveIcon(name: "unknown.xyz", nodeType: .file)
        #expect(icon == "file")
    }

    @Test("Source order preserved for siblings")
    func sourceOrderPreserved() throws {
        let source = """
        treeView-beta
            z.js
            a.js
            m.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].name == "z.js")
        #expect(result.root.children[1].name == "a.js")
        #expect(result.root.children[2].name == "m.js")
    }

    @Test("Explicit icon overrides resolved icon")
    func explicitIconOverrides() throws {
        let source = """
        treeView-beta
            Dockerfile icon(database)
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].iconId == "database")
    }

    @Test("Description sanitization escapes HTML")
    func descriptionSanitization() throws {
        let source = """
        treeView-beta
            file.js ## <script>alert('xss')</script>
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let desc = result.root.children[0].description
        #expect(desc?.contains("&lt;") == true)
        #expect(desc?.contains("<script>") == false)
    }

    @Test("getIconPath returns fallback for unknown id")
    func iconPathFallback() {
        let path = getIconPath(iconId: "nonexistent")
        #expect(!path.isEmpty)
        #expect(path == getIconPath(iconId: "file"))
    }

    @Test("getIconPath returns correct path for known id")
    func iconPathKnown() {
        let path = getIconPath(iconId: "folder")
        #expect(path.hasPrefix("M10,4"))
    }

    @Test("Ported icon paths match Mermaid source for representative complex icons")
    func iconPathParityWithMermaid() {
        #expect(getIconPath(iconId: "docker").hasPrefix("M21.81 10.25"))
        #expect(getIconPath(iconId: "go").hasPrefix("M2.64,10.33"))
        #expect(getIconPath(iconId: "csharp").contains("13.89,19L14.5,15"))
    }
}
