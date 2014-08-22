/**
 * @name: Flash Uploader
 * @author Jony
 **/
package
{
    import flash.display.*;
    import flash.events.*;
    import flash.external.ExternalInterface;
    import flash.net.FileFilter;
    import flash.net.FileReference;
    import flash.net.FileReferenceList;
    import flash.net.URLRequest;
    import flash.net.URLRequestMethod;
    import flash.net.URLVariables;
    import flash.utils.Dictionary;
    import flash.utils.ByteArray;
    import JPEGEncoder;

    public class uploader extends Sprite
    {
        private var flashvars:Object = LoaderInfo(parent.loaderInfo).parameters;
        private var counter:Number = 0;
        private var files:Object;
        private var fileIDs:Dictionary;
        private var fileRef:FileReference;
        private var fileRefList:FileReferenceList;
        private var vars:URLVariables;
        private var active:String = "";
        private var loadState:String;
        private var allowedType:String = flashvars['allowedType'] || 'image';
        private var allowedExts:Array = flashvars['allowedExts'] ? flashvars['allowedExts'].split(',') : new Array('jpg', 'jpeg', 'gif', 'png');
        private var ext:String;
        private    var extPattern:RegExp = /(.*)\.([a-z0-9]*)$/gi;
        private static const _encodeChars:Vector.<int> = InitEncoreChar();
        
        private const STATE_CACHE:String = "cache";
        private const STATE_UPLOAD:String = "upload";

        //Javascript 可监听的事件
        private const MOUSE_CLICK:String         = "onMouseClick";        // 点击Flash按钮
        private const FILES_SELECT:String        = "onSelected";            // 当选择了文件
        private const UPLOAD_START:String        = "onStart";                // 当一个文件开始上传时
        private const UPLOAD_ERROR:String        = "onError";                // 当发生错误的时候
        private const UPLOAD_SUCCESS:String      = "onSuccess";            // 当一个文件成功上传时
        private const UPLOAD_PROGRESS:String     = "onProgress";            // 上传进度改变的时候
        private const UPLOAD_CANCEL:String       = "onCancel";            // 当取消一个上传时
        private const UPLOAD_QUEUE_CLEAR:String  = "onClearQueue";        // 当队列被清空时

        public function uploader() {
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.showDefaultContextMenu = false;
            files   = {};
            fileIDs = new Dictionary();

            stage.addEventListener(MouseEvent.CLICK, clickBtn);
            // 注册 Javascript 回调
            ExternalInterface.addCallback("startUpload",  startUpload);
            ExternalInterface.addCallback("cancelUpload", cancelUpload);
            //ExternalInterface.addCallback("getFile",    getFile);
            ExternalInterface.addCallback("setData",    setData);
            
            if (!flashvars.formData) flashvars.formData = '';
        }
        
        private function clickBtn(e:MouseEvent):void {
            if (active == "") {
                fileHandler(e);
                select();
            }
        }

        //打开选择文件窗口
        private function select():Boolean {
            var i:int = 0;
            var type:Object;
            var filter:Array = new Array();

            counter = 0;
            
            if (flashvars.desc != "" && flashvars.ext != "") {
                var descriptions:Array = flashvars.desc.split('|');
                var extensions:Array = flashvars.ext.split('|');
                for (var n:int = 0; n < descriptions.length; n++)
                    filter.push( new FileFilter(descriptions[n], '*.' + extensions[n].replace(/,/g, ';*.')) );
            }
            if (flashvars.multiple) {
                fileRefList = new FileReferenceList();
                fileRefList.addEventListener(Event.SELECT, fileHandler);
                fileRefList.addEventListener(Event.CANCEL, fileHandler);
                return filter.length ? fileRefList.browse(filter) : fileRefList.browse();
            } else {
                fileRef = new FileReference();
                fileRef.addEventListener(Event.SELECT, fileHandler);
                fileRef.addEventListener(Event.CANCEL, fileHandler);
                return filter.length ? fileRef.browse(filter) : fileRef.browse();
            }
        }

        //根据id上传文件
        public function startUpload(id:String = '0'):void {
            var action:String = flashvars.action,
                req:URLRequest,
                file:FileReference;

            if (active != "" || objSize(files) == 0) return;

            if (action.substr(0,1) != '/' && action.substr(0,4) != 'http') action = flashvars.path + action;

            req = new URLRequest(action);
            req.method = (flashvars.method && flashvars.method === "GET") ? URLRequestMethod.GET : URLRequestMethod.POST;
            
            vars = new URLVariables();
            if (flashvars.formData != '') vars.decode(decodeURIComponent(flashvars.formData));
            req.data = vars;

            file = getFileRef(id);
            active = id;
            loadState = STATE_UPLOAD;
            file.upload(req, flashvars.field || 'file');
        }

        //根据id取消文件上传
        public function cancelUpload(id:String):void {
            var file:FileReference;
            
            if (id == '*') {
                active = "";
                files = {};
                fileHandler({
                    type: UPLOAD_QUEUE_CLEAR
                });
                return;
            }
            
            file = getFileRef(id);
            if (!file) return;
            file.cancel();
            delete files[id];
            if (active == id) active = "";
            fileHandler({
                type: UPLOAD_CANCEL,
                target: file
            });
        }

        /*public function getFile(id:String):Object {
            if (!validId(id)) return null;
            //ExternalInterface.call("console.log", getFileObject(getFileRef(id)));
            return getFileObject(getFileRef(id));
        }*/

        public function getFiles(arrFiles:Array):Array {
            var ret:Array = [],
                i:int = 0;
                
            while (i < arrFiles.length) {
                ret.push(getFileObject(arrFiles[i]));
                i++;
            }
            return ret;
        }

        public function setData(data:String):void {
            flashvars.formData = data;
        }

        private function validId(id:String):Boolean {
            return id in files;
        }

        private function addFiles(objFiles:Object):Array {
            var ret:Array = [];
            var i:int = 0;

            if (objFiles is FileReference) {
                ret.push(objFiles);
            } else if (objFiles is FileReferenceList) {
                ret = objFiles.fileList;
            }
            while (i < ret.length) {
                addFile(ret[i]);
                i++;
            }

            return ret;
        }

        private function addFile(file:FileReference):String {
            var id:String = String(counter++);

            files[id] = file;
            fileIDs[file] = id;

            file.addEventListener(Event.OPEN, fileHandler);
            file.addEventListener(DataEvent.UPLOAD_COMPLETE_DATA, fileHandler);
            file.addEventListener(ProgressEvent.PROGRESS, fileHandler);
            //注册异常
            file.addEventListener(HTTPStatusEvent.HTTP_STATUS, fileHandler);
            file.addEventListener(IOErrorEvent.IO_ERROR, fileHandler);
            file.addEventListener(SecurityErrorEvent.SECURITY_ERROR, fileHandler);
            
            if (flashvars.preview) {
                // 检查文件后缀
                ext = file.name.replace(extPattern, '$2').toLowerCase();
                if (allowedExts.indexOf(ext) !== -1) {
                    loadState = STATE_CACHE;
                    var loader:Loader = new Loader();
                    loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):void {
                        var bmd:BitmapData = Bitmap(e.target.content).bitmapData;
                        var quality:Number = 30;
                        if (flashvars.previewSize) {
                            quality = Number(((flashvars.previewSize * 100) / (file.size * 5)).toFixed(1));
                        }
                        var data:ByteArray = new JPEGEncoder(quality).encode(bmd);
                        var dataURL:String = 'data:' + allowedType + '/' + ext + ';base64,' + encode(data);
                        callJS("setPreview", {id: id, dataURL: dataURL});
                    });
                    file.addEventListener(Event.COMPLETE, function(e:Event):void {
                        if (loadState == STATE_CACHE) {
                            loader.loadBytes(e.target.data);
                        }
                    });
                    file.load();
                }
            }

            return id;
        }

        private function fileId(file:FileReference):String {
            return (file in fileIDs) ? fileIDs[file] : null;
        }

        private function getFileObject(file:FileReference):Object {
            return {
                id: fileId(file),
                name: file.name,
                size: file.size,
                type: file.type.substr(1),
                lastModifiedDate: file.modificationDate.getTime()
            };
        }

        private function getFileRef(id:String):FileReference {
            return validId(id) ? files[id] : null;
        }
        
        // 文件相关事件
        private function fileHandler(e:Object):void {
            var ret:Object = {};
            var callback:String;
            var isComplete:Boolean = false;
            var id:String = null;

            if (e.target is FileReference) {
                id = fileId(e.target);
            }
            if (id) ret.id = id;
            switch (e.type) {
                case Event.SELECT:
                    var fArr:Array;
                    callback  = FILES_SELECT;
                    fArr      = addFiles(e.target);
                    ret = getFiles(fArr);
                    break;

                case Event.OPEN:
                    if (loadState == STATE_UPLOAD) {
                        callback = UPLOAD_START;
                        ret.type  = 'loadstart';
                        ret.lengthComputable = false;
                        ret.loaded = 0;
                        ret.total = 0;
                        ret.timeStamp = (new Date()).getTime();
                    }
                    break;

                case ProgressEvent.PROGRESS:
                    if (loadState == STATE_UPLOAD) {
                        callback  = UPLOAD_PROGRESS;
                        ret.type  = 'progress';
                        ret.lengthComputable = true;
                        ret.loaded = e.bytesLoaded;
                        ret.total  = e.bytesTotal;
                        ret.timeStamp = (new Date()).getTime();
                    }
                    break;

                case DataEvent.UPLOAD_COMPLETE_DATA:
                    if (loadState == STATE_UPLOAD) {
                        callback  = UPLOAD_SUCCESS;
                        ret.data = e.data.replace(/\\/g, "\\\\");
                        delete files[id];
                        active = "";
                        if (objSize(files) === 0) {
                            counter = 0;
                        }
                    }
                    break;
                
                //异常
                case HTTPStatusEvent.HTTP_STATUS:
                    callback = UPLOAD_ERROR;
                    ret.name = 'HTTP Error';
                    ret.message = e.status; //http状态码
                    delete files[id];
                    active = "";
                    break;

                case IOErrorEvent.IO_ERROR:
                    callback = UPLOAD_ERROR;
                    ret.name = 'IO Error';
                    ret.message = e.text;
                    break;
                    
                case SecurityErrorEvent.SECURITY_ERROR:
                    callback = UPLOAD_ERROR;
                    ret.name = 'Security Error';
                    ret.message = e.text;
                    break;

                case UPLOAD_CANCEL:
                    callback = UPLOAD_CANCEL;
                    ret = id;
                    break;
                    
                case UPLOAD_QUEUE_CLEAR:
                    callback = UPLOAD_QUEUE_CLEAR;
                    counter = 0;
                    ret = 'ok';
                    break;
                    
                case MouseEvent.CLICK:
                    callback = MOUSE_CLICK;
                    ret = null;
                    break;
                default: return;
            }
            
            if (callback) callJS(callback, ret);
        }
        
        private function objSize(obj:Object):Number {
            var i:int = 0;
            for (var item in obj)
                i++;
            return i;
        }
        
        private function callJS(type:String, o:Object):void {
            if (flashvars.debug && o) log(o);
            ExternalInterface.call(flashvars.id + "." + type, o);
        }
        
        private function log(o:*):void {
            ExternalInterface.call("console.log", 'Flash >>> ');
            ExternalInterface.call("console.log", o);
        }
        
        /* 
        * Copyright (C) 2012 Jean-Philippe Auclair 
        * Licensed under the MIT license: http://www.opensource.org/licenses/mit-license.php 
        * Base64 library for ActionScript 3.0. 
        * By: Jean-Philippe Auclair : http://jpauclair.net 
        * Based on article: http://jpauclair.net/2010/01/09/base64-optimized-as3-lib/ 
        * Benchmark: 
        * This version: encode: 260ms decode: 255ms 
        * Blog version: encode: 322ms decode: 694ms 
        * as3Crypto encode: 6728ms decode: 4098ms 
        * 
        * Encode: com.sociodox.utils.Base64 is 25.8x faster than as3Crypto Base64 
        * Decode: com.sociodox.utils.Base64 is 16x faster than as3Crypto Base64 
        * 
        * Optimize & Profile any Flash content with TheMiner ( http://www.sociodox.com/theminer ) 
        */
        private static function encode(data:ByteArray):String {
            var out:ByteArray = new ByteArray();
            //Presetting the length keep the memory smaller and optimize speed since there is no "grow" needed
            out.length = (2 + data.length - ((data.length + 2) % 3)) * 4 / 3; //Preset length //1.6 to 1.5 ms
            var i:int = 0;
            var r:int = data.length % 3;
            var len:int = data.length - r;
            var c:uint; //read (3) character AND write (4) characters
            var outPos:int = 0;
            while (i < len)    {
                //Read 3 Characters (8bit * 3 = 24 bits)
                c = data[int(i++)] << 16 | data[int(i++)] << 8 | data[int(i++)];
                
                out[int(outPos++)] = _encodeChars[int(c >>> 18)];
                out[int(outPos++)] = _encodeChars[int(c >>> 12 & 0x3f)];
                out[int(outPos++)] = _encodeChars[int(c >>> 6 & 0x3f)];
                out[int(outPos++)] = _encodeChars[int(c & 0x3f)];
            }
            
            if (r == 1) { // Need two "=" padding
                //Read one char, write two chars, write padding
                c = data[int(i)];
                
                out[int(outPos++)] = _encodeChars[int(c >>> 2)];
                out[int(outPos++)] = _encodeChars[int((c & 0x03) << 4)];
                out[int(outPos++)] = 61;
                out[int(outPos++)] = 61;
            } else if (r == 2) { //Need one "=" padding
                c = data[int(i++)] << 8 | data[int(i)];
                
                out[int(outPos++)] = _encodeChars[int(c >>> 10)];
                out[int(outPos++)] = _encodeChars[int(c >>> 4 & 0x3f)];
                out[int(outPos++)] = _encodeChars[int((c & 0x0f) << 2)];
                out[int(outPos++)] = 61;
            }
            
            return out.readUTFBytes(out.length);
        }
        
        private static function InitEncoreChar():Vector.<int> {
            var encodeChars:Vector.<int> = new Vector.<int>(64, true);
            
            // We could push the number directly
            // but I think it's nice to see the characters (with no overhead on encode/decode)
            var chars:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
            for (var i:int = 0; i < 64; i++) {
                encodeChars[i] = chars.charCodeAt(i);
            }
            
            return encodeChars;
        }
    }
}