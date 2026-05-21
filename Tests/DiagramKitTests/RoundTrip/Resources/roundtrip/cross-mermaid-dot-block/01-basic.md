block-beta
    columns 3
    block:frontend["Frontend"]
        columns 1
        webapp["Web App"]
        mobile["Mobile App"]
    end
    block:backend["Backend"]
        columns 1
        api["API"]
        worker["Worker"]
    end
    block:data["Data"]
        columns 1
        db["DB"]
        cache["Cache"]
    end
    frontend --> backend
    backend --> data
