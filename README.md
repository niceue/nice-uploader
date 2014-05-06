## Uploader
Multiple file upload jQuery plugin with progress-bar, using html5 and flash technology.


### Usage
Include resources:
``` html
<link rel="stylesheet" href="path/to/jquery.uploader.css">
<script type="text/javascript" src="path/to/jquery.uploader.js"></script>
```

Initialization：
``` js
$("#upload_btn").uploader({
    action: 'upload.php',
    onSuccess: function(){
        //do something..
    }
});
```

### Documention
[简体中文](http://niceue.com/uploader/)

### API

- `mode`: "html5"
- `action`: ""
- `name`: "file"
- `formData`: null `{object|function}`
- `multiple`: false
- `auto`: true  
- `showQueue`: false
- `fileSizeLimit`: 0
- `fileTypeDesc`: ""
- `fileTypeExts`: ""
- `onInit`: noop
- `onClearQueue`: noop
- `onSelected`: noop
- `onCancel`: noop
- `onError`: noop
- `onStart`: noop
- `onProgress`: noop
- `onSuccess`: noop
- `onComplete`: noop
- `onAllComplete`: noop
- `onMouseOver`: noop
- `onMouseOut`: noop
- `onMouseClick`: noop
- `onAddQueue`: default function


##### Begin upload 
`$("#upload_btn").uploader("start");`

##### Cancel upload first file 
`$("#upload_btn").uploader("cancel", 0);`

##### Cancel upload all files 
`$("#upload_btn").uploader("cancel", "*");`


### Dependencies
[jQuery 1.7+](http://jquery.com)

### Browser Support
  * IE6+
  * Chrome
  * Safari 4+
  * Firefox 3.5+
  * Opera


### Bugs / Contributions
- [Report a bug](https://github.com/niceue/uploader/issues)
- To contribute or send an idea, github message me or fork the project


### Build
Uploader use [UglifyJS2](https://github.com/mishoo/UglifyJS) 
you should have installed [nodejs](nodejs.org) and run `npm install uglify-js -g`.

  
### License
[MIT License](https://github.com/niceue/uploader/blob/master/LICENSE.txt).
