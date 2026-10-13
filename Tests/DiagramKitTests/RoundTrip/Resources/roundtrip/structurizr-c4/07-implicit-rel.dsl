workspace {
  model {
    a = softwareSystem "Alpha" {
      -> b "Uses"
    }
    b = softwareSystem "Beta"
  }
  views {
    systemContext a {
      include *
    }
  }
}
