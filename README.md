# contacts

## Purpose

_This POC works with RxSwift doing a Contacts CRUD app for iOS._

## Using firebase

_Firebase is the repository of data, there's no reason to use firebase api here, just for the poc we can do a simple URLSession to get and put information using json like:_

```json
{
    "KqesW2LmWt8qo6ymbmh": {
        "last": "Smith",
        "first": "John",
        "dob": "1980-01-01",
        "phone": "33341955",
        "zip": 8400
    },
    "xxxxxxxxxxxxxxxxxxx": {
        "first": "Jane",
        "last": "Doe",
        "dob": "1990-11-01",
        "phone": "335123455",
        "zip": 8540
    }
}

```

### Get all the contacts

_Using Reactive programming getting all the contact information in a table view:_

Screen shoot: [this](screenshoots/main.png)

#### Rest:
```bash
curl 'https://contacts-4c754.firebaseio.com/.json'
```


### Add info

Screen shoot: [this](screenshoots/contactadd.png)

#### Rest:

```
curl -X POST -d '{ "first": "Lio", "last": "Messi", "dob": "1913-01-01", "phone": "11132345", "zip": 3345, "url": ["http://the-toast.net/wp-content/uploads/2016/05/rocky-mountain-high-a-john-denver-tribute-show-detail.jpg"]  }' https://contacts-4c754.firebaseio.com/.json
```



### Change info about a contact

Screen shoot: [this](screenshoots/contactedition.png)

#### Rest:

```
curl -X PATCH -d '{ "dob": "1982-02-02" }' https://contacts-4c754.firebaseio.com/-KqesW2LmWt8qo6ymbmh.json
```

### Delete a contact

Screen shoot: [this](screenshoots/contactdelete.png)

#### Rest:
```
curl -X DELETE https://contacts-4c754.firebaseio.com/-KqesW2LmWt8qo6ymbmh.json
```

### Search by first/last names
Screen shoot: [this](screenshoots/contactedition.png)

## Authentication

There is no authentication needed here, just get/put all the information, and shared contact database all over the application/devices.


