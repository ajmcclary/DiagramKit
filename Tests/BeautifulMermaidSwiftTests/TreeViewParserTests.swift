import Testing
@testable import BeautifulMermaid

@Suite("TreeView Parser")
struct TreeViewParserTests {

    @Test("Parses empty treeView-beta")
    func emptyTree() throws {
        let source = "treeView-beta\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children.isEmpty)
        #expect(result.nodes.count == 1)
        #expect(result.root.id == 0)
        #expect(result.root.level == -1)
        #expect(result.root.name == "/")
    }

    @Test("Parses single file node")
    func singleFileNode() throws {
        let source = """
        treeView-beta
            file.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children.count == 1)
        #expect(result.root.children[0].name == "file.js")
        #expect(result.root.children[0].nodeType == .file)
        #expect(result.root.children[0].id == 1)
    }

    @Test("Parses directory trailing slash")
    func directoryTrailingSlash() throws {
        let source = """
        treeView-beta
            src/
                index.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children.count == 1)
        #expect(result.root.children[0].name == "src")
        #expect(result.root.children[0].nodeType == .directory)
        #expect(result.root.children[0].children.count == 1)
        #expect(result.root.children[0].children[0].name == "index.js")
    }

    @Test("Parses double-quoted labels")
    func doubleQuotedLabels() throws {
        let source = """
        treeView-beta
            "my project"
                "folder with spaces"
                    "file.js"
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children.count == 1)
        #expect(result.root.children[0].name == "my project")
        #expect(result.root.children[0].children[0].name == "folder with spaces")
    }

    @Test("Parses single-quoted labels")
    func singleQuotedLabels() throws {
        let source = """
        treeView-beta
            'single'
                'child'
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].name == "single")
        #expect(result.root.children[0].children[0].name == "child")
    }

    @Test("Parses empty quoted name")
    func emptyQuotedName() throws {
        let source = """
        treeView-beta
            ""
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children.count == 1)
        #expect(result.root.children[0].name == "")
    }

    @Test("Parses title and accessibility")
    func titleAndAccessibility() throws {
        let source = """
        treeView-beta
        title Project Tree
        accTitle: Project files
        accDescr: Directory structure
        "Root"
            "Child"
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.diagramTitle == "Project Tree")
        #expect(result.accTitle == "Project files")
        #expect(result.accDescr == "Directory structure")
    }

    @Test("Parses multiline accDescr")
    func multilineAccDescr() throws {
        let source = """
        treeView-beta
        accDescr {
        Line one
        Line two
        }
        "Root"
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.accDescr == "Line one Line two")
    }

    @Test("Parses inline accDescr")
    func inlineAccDescr() throws {
        let source = """
        treeView-beta
        accDescr { Short description }
        "Root"
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.accDescr == "Short description")
    }

    @Test("Parses CSS class annotation")
    func cssClassAnnotation() throws {
        let source = """
        treeView-beta
            file.js :::highlight
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].cssClass == "highlight")
    }

    @Test("Parses icon annotation")
    func iconAnnotation() throws {
        let source = """
        treeView-beta
            App.tsx icon(react)
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].iconId == "react")
    }

    @Test("Parses icon(none) suppression")
    func iconNoneSuppression() throws {
        let source = """
        treeView-beta
            file.js icon(none)
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].iconId == "none")
    }

    @Test("Parses empty icon() suppression")
    func emptyIconSuppression() throws {
        let source = """
        treeView-beta
            file.js icon()
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].iconId == "none")
    }

    @Test("Parses description annotation")
    func descriptionAnnotation() throws {
        let source = """
        treeView-beta
            file.js ## entry point
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].description?.contains("entry point") == true)
    }

    @Test("Parses annotations in any order")
    func annotationsAnyOrder() throws {
        let source = """
        treeView-beta
            App.tsx :::highlight icon(react) ## main component
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].cssClass == "highlight")
        #expect(result.root.children[0].iconId == "react")
        #expect(result.root.children[0].description?.contains("main component") == true)
    }

    @Test("Parses multiple root nodes")
    func multipleRootNodes() throws {
        let source = """
        treeView-beta
            src/
                index.js
            package.json
            README.md
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children.count == 3)
        #expect(result.root.children[0].name == "src")
        #expect(result.root.children[1].name == "package.json")
        #expect(result.root.children[2].name == "README.md")
    }

    @Test("Parses comments between nodes")
    func commentsBetweenNodes() throws {
        let source = """
        treeView-beta
            file1.js
        %% this is a comment
            file2.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children.count == 2)
        #expect(result.root.children[0].name == "file1.js")
        #expect(result.root.children[1].name == "file2.js")
    }

    @Test("Header is case-sensitive")
    func headerCaseSensitive() throws {
        let source = "TreeView-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(throws: TreeViewParserError.self) {
            _ = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        }
    }

    @Test("Rejects treeview-beta lowercase v")
    func rejectsLowerV() throws {
        let source = "treeview-beta\n    file.js\n"
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(throws: TreeViewParserError.self) {
            _ = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        }
    }

    @Test("Parses dotfiles and special filenames")
    func dotfilesAndSpecial() throws {
        let source = """
        treeView-beta
            .env
            .gitignore
            Dockerfile
            package.json
            tsconfig.json
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children.count == 5)
        #expect(result.root.children[0].name == ".env")
        #expect(result.root.children[1].name == ".gitignore")
    }

    @Test("Parses deep nesting")
    func deepNesting() throws {
        let source = """
        treeView-beta
            a/
                b/
                    c/
                        d.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        let a = result.root.children[0]
        let b = a.children[0]
        let c = b.children[0]
        #expect(c.children[0].name == "d.js")
    }

    @Test("Parses blank lines")
    func blankLines() throws {
        let source = """
        treeView-beta

            file.js

        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children.count == 1)
    }

    @Test("Rejects empty source")
    func emptySource() throws {
        #expect(throws: TreeViewParserError.self) {
            _ = try parseTreeViewDiagram([], frontmatter: nil)
        }
    }

    @Test("Icon resolution: directory gets folder icon")
    func iconResolutionDirectory() throws {
        let source = """
        treeView-beta
            src/
                file.js
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].iconId == "folder")
    }

    @Test("Icon resolution: known filename")
    func iconResolutionFilename() throws {
        let source = """
        treeView-beta
            Dockerfile
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].iconId == "docker")
    }

    @Test("Icon resolution: extension match")
    func iconResolutionExtension() throws {
        let source = """
        treeView-beta
            app.tsx
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].iconId == "react")
    }

    @Test("Icon resolution: fallback to file")
    func iconResolutionFallback() throws {
        let source = """
        treeView-beta
            unknown.xyz
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].iconId == "file")
    }

    @Test("Parses bare labels with spaces and annotations")
    func bareLabelsWithAnnotations() throws {
        let source = """
        treeView-beta
            App.tsx :::highlight icon(react)
            index.js ## entry point
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].name == "App.tsx")
        #expect(result.root.children[0].cssClass == "highlight")
        #expect(result.root.children[0].iconId == "react")
    }

    @Test("Parses bare directory with spaces (no quotes)")
    func bareDirectoryWithSpaces() throws {
        let source = """
        treeView-beta
            My Documents/
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].name == "My Documents")
        #expect(result.root.children[0].nodeType == .directory)
        #expect(result.root.children[0].iconId == "folder")
    }

    @Test("Parses bare directory with spaces and class annotation")
    func bareDirectoryWithSpacesAndClass() throws {
        let source = """
        treeView-beta
            My Documents/ :::highlight
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].name == "My Documents")
        #expect(result.root.children[0].nodeType == .directory)
        #expect(result.root.children[0].cssClass == "highlight")
    }

    @Test("Parses bare file with spaces and description (no quotes)")
    func bareFileWithSpacesAndDescription() throws {
        let source = """
        treeView-beta
            my file.ts ## some description
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].name == "my file.ts")
        #expect(result.root.children[0].nodeType == .file)
        #expect(result.root.children[0].iconId == "typescript")
        #expect(result.root.children[0].description == "some description")
    }

    @Test("Parses empty ## description as nil")
    func emptyDescriptionIsNil() throws {
        let source = """
        treeView-beta
            file.txt ##
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].name == "file.txt")
        #expect(result.root.children[0].description == nil)
    }

    @Test("Parses icon(none) combined with class and description")
    func iconNoneWithOtherAnnotations() throws {
        let source = """
        treeView-beta
            app.ts icon(none) :::highlight ## entry point
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].name == "app.ts")
        #expect(result.root.children[0].iconId == "none")
        #expect(result.root.children[0].cssClass == "highlight")
        #expect(result.root.children[0].description == "entry point")
    }

    @Test("Parses directory with class annotation")
    func directoryWithClassAnnotation() throws {
        let source = """
        treeView-beta
            src/ :::highlight
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].name == "src")
        #expect(result.root.children[0].nodeType == .directory)
        #expect(result.root.children[0].cssClass == "highlight")
        #expect(result.root.children[0].iconId == "folder")
    }

    @Test("Parses class annotation with hyphens")
    func classAnnotationWithHyphens() throws {
        let source = """
        treeView-beta
            file.ts :::my-class
        """
        let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let result = try parseTreeViewDiagram(rawLines, frontmatter: nil)
        #expect(result.root.children[0].cssClass == "my-class")
    }
}
