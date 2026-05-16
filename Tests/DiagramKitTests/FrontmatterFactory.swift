import DiagramKitModel

extension DiagramFrontmatter {
    /// Test sugar for constructing a frontmatter with typed-section
    /// mutations. Replaces the legacy 49-arg flat init with a closure
    /// that mutates an empty frontmatter and returns it.
    ///
    ///     let fm = DiagramFrontmatter.with { $0.perDiagram.pie.config = pieCfg }
    static func with(_ mutate: (inout DiagramFrontmatter) -> Void) -> DiagramFrontmatter {
        var fm = DiagramFrontmatter()
        mutate(&fm)
        return fm
    }
}
