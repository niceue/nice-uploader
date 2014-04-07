/**
 * @name: Flash Uploader
 * @author Jony
 **/
package
{
	import flash.display.*;
	import flash.events.*;
	import flash.external.ExternalInterface;
	import flash.net.*;
	import flash.utils.*;

	public class uploader extends Sprite
	{
		private var param:Object = LoaderInfo(parent.loaderInfo).parameters;
		private var counter:Number = 0;
		private var files:Object;
		private var fileIDs:Dictionary;
		private var fileRef:FileReference;
		private var fileRefList:FileReferenceList;
		private var vars:URLVariables;
		private var active:String = "";

		//Javascript 可监听的事件
		static public const MOUSE_CLICK:String         = "onMouseClick";		// 点击Flash按钮
		static public const FILES_SELECT:String        = "onSelected";			// 当选择了文件
		static public const UPLOAD_START:String        = "onStart";				// 当一个文件开始上传时
		static public const UPLOAD_ERROR:String        = "onError";				// 当发生错误的时候
        static public const UPLOAD_SUCCESS:String      = "onSuccess";		    // 当一个文件成功上传时
		static public const UPLOAD_PROGRESS:String     = "onProgress";			// 上传进度改变的时候
		static public const UPLOAD_CANCEL:String       = "onCancel";			// 当取消一个上传时
		static public const UPLOAD_QUEUE_CLEAR:String  = "onClearQueue";		// 当队列被清空时

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
			//ExternalInterface.addCallback("setData",    setData);
			
			if (!param.formData) param.formData = '';
		}
        
        private function clickBtn(e:MouseEvent):void {
            if (active == "") {
                triggerJS(e);
                select();
            }
		}
        
        private function formatExt(str:String):String {
            return str.split(',').map(function(elem:String):String{return '*.' + elem;}).join(';');
        }

        //打开选择文件窗口
		private function select():Boolean {
			var i:int = 0;
			var type:Object;
			var filter:Array = new Array();

            counter = 0;
            
			if (param.desc != "" && param.ext != "") {
				var descriptions:Array = param.desc.split('|');
				var extensions:Array = param.ext.split('|');
				for (var n:int = 0; n < descriptions.length; n++)
					filter.push( new FileFilter(descriptions[n], '*.' + extensions[n].replace(/,/g, ';*.')) );
			}
			if (param.multiple) {
				fileRefList = new FileReferenceList();
				fileRefList.addEventListener(Event.SELECT, triggerJS);
				fileRefList.addEventListener(Event.CANCEL, triggerJS);
				return filter.length ? fileRefList.browse(filter) : fileRefList.browse();
			} else {
				fileRef = new FileReference();
				fileRef.addEventListener(Event.SELECT, triggerJS);
				fileRef.addEventListener(Event.CANCEL, triggerJS);
				return filter.length ? fileRef.browse(filter) : fileRef.browse();
			}
		}

        //根据id上传文件
		public function startUpload(id:String = '0'):void {
			var action:String = param.action,
                req:URLRequest,
                file:FileReference;

			if (active != "" || objSize(files) == 0) return;

			if (action.substr(0,1) != '/' && action.substr(0,4) != 'http') action = param.path + action;

			req = new URLRequest(action);
            req.method = (param.method && param.method === "GET") ? URLRequestMethod.GET : URLRequestMethod.POST;
            
            vars = new URLVariables();
			if (param.formData != '') vars.decode(unescape(param.formData));
            req.data = vars;

			file = getFileRef(id);
            active = id;
            file.upload(req, param.field || 'file');
		}

        //根据id取消文件上传
		public function cancelUpload(id:String):void {
			var file:FileReference;
            
            if (id == '*') {
                active = "";
                files = {};
                triggerJS({
                    type: UPLOAD_QUEUE_CLEAR
                });
                return;
            }
			
            file = getFileRef(id);
            if (!file) return;
            file.cancel();
            delete files[id];
            if (active == id) active = "";
            triggerJS({
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

		/*public function setData(data:String):void {
			param.formData = data;
		}*/

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

			file.addEventListener(Event.OPEN, triggerJS);
			file.addEventListener(DataEvent.UPLOAD_COMPLETE_DATA, triggerJS);
			file.addEventListener(ProgressEvent.PROGRESS, triggerJS);
            //注册异常
			file.addEventListener(HTTPStatusEvent.HTTP_STATUS, triggerJS);
			//file.addEventListener(IOErrorEvent.IO_ERROR, triggerJS);
            //file.addEventListener(SecurityErrorEvent.SECURITY_ERROR, triggerJS);

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
				//creationDate: file.creationDate.getTime(),
				lastModifiedDate: file.modificationDate.getTime()
			};
		}

		private function getFileRef(id:String):FileReference {
			return validId(id) ? files[id] : null;
		}

        //触发JS事件
		private function triggerJS(e:Object):void {
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
					callback = UPLOAD_START;
                    ret.type  = 'loadstart';
                    ret.loaded = 0;
                    ret.total = 0;
                    ret.timeStamp = (new Date()).getTime();
					break;

				case ProgressEvent.PROGRESS:
					callback  = UPLOAD_PROGRESS;
                    ret.type  = 'progress';
                    ret.lengthComputable = true;
					ret.loaded = e.bytesLoaded;
					ret.total  = e.bytesTotal;
                    ret.timeStamp = (new Date()).getTime();
					break;

                case DataEvent.UPLOAD_COMPLETE_DATA:
					callback  = UPLOAD_SUCCESS;
					ret = e.data.replace(/\\/g, "\\\\");
					delete files[id];
					active = "";
                    if (objSize(files) === 0) {
                        counter = 0;
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

				/*case IOErrorEvent.IO_ERROR:
                    callback = UPLOAD_ERROR;
					ret.name = 'IO Error';
                    ret.message = e.text;
                    break;
                    
				case SecurityErrorEvent.SECURITY_ERROR:
					callback = UPLOAD_ERROR;
					ret.name = 'Security Error';
                    ret.message = e.text;
					break;
                */  
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
			callJS(callback, ret);
            
            /*if (param.debug) {
                if (ret) debug(callback, ret);
            }*/
		}
		
		private function objSize(obj:Object):Number {
			var i:int = 0;
			for (var item in obj)
				i++;
			return i;
		}
        
        private function callJS(type:String, o:Object):void {
            ExternalInterface.call(param.id + "." + type, o);
        }
        
        /*
        private function log(o:Object):void {
            ExternalInterface.call("console.log", o);
        }
        
        private function debug(type:String, o:*):void {
            log('Flash >>> ' + type + ':')
            log(o);
        }*/
	}
}