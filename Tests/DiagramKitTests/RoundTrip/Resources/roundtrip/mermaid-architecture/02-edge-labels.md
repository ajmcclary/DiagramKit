architecture-beta
    title Edge Variants
    group core(cloud)[Core]
    service db(database)[DB] in core
    service api(server)[API] in core
    service ext(internet)[Ext]
    db:R -[SQL]- L:api
    api:T <-- B:ext
    ext:R -[HTTPS]- L:db
