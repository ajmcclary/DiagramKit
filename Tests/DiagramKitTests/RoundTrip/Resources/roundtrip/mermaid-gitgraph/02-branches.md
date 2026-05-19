gitGraph
    commit id: "init"
    branch develop
    branch feature
    checkout feature
    commit tag: "v0.1"
    checkout develop
    commit
    merge feature
    checkout main
    merge develop tag: "release-1.0"
    commit type: HIGHLIGHT
