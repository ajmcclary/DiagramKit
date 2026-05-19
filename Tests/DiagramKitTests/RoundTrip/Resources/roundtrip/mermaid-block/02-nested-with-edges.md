block-beta
    columns 3
    block:frontend["Frontend"]
        columns 1
        WebApp
        MobileApp
    end
    block:backend["Backend"]
        columns 1
        API
        Workers
    end
    block:data["Data"]
        columns 1
        DB
        Cache
    end
    frontend --> backend
    backend --> data
