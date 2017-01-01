package;

import format.png.*;
import haxe.Json;
import haxe.Utf8;
import haxe.io.Bytes;
import neko.Lib;
import sys.FileSystem;
import sys.io.File;

using StringTools;
using Spirit;

/**
 * Spirit - The Sprite Sheet ToolKit CLI
 */
class Spirit
{
    private var argKeys:Array<String> = [
        "from",
        "to",
        "ext",
        "convert",
        "remove",
        "format",
        "verbose",
        "autoImagePath",
        "autoFrameName",
        "unpack",
        "convert"
    ];

    private var argValues:Dynamic = {};

    private var from:String;
    private var to:String;
    private var ext:String;
    private var remove:String;
    private var format:String;
    private var verbose:String;
    private var autoImagePath:String;
    private var autoFrameName:String;
    private var unpack:String;
    private var convert:String;

    private var items:Array<String>;

    static function main()
    {
        new Spirit();
    }

    public function new()
    {
        if (parseArgs())
        {
            if (remove == "true") {
                removeDirectory(to);
            }
            if (!FileSystem.exists(to)) FileSystem.createDirectory(to);
            items = [];
            // fill items
            recurse(from);
            for (item in items)
            {
                if(ext == "xml") {
                    if(unpack == "true") {
                        doXmlUnpack(item);
                    } else {
                        doXmlToJsonConversion(item);
                    }                    
                } else if(ext == "json") {
                    if(unpack == "true") {
                        doJsonUnpack(item);
                    } else {
                        doJsonToXmlConversion(item);
                    } 
                }
            }
        }
    }
    
    private function doJsonUnpack(file:String):Void
    {
        var fromFile = file;
        var fileName = file.substr(from.length + 1, file.lastIndexOf(".") - (from.length + 1));
        var s = File.getContent(fromFile);
        var data = Json.parse(s);        
        if (verbose == "true") {
            Lib.println("Processing: " + file);
        }
        var frames = Reflect.field(data, 'frames');
        var meta = Reflect.field(data, 'meta');
        var imageName = Reflect.field(meta, 'image'); 
        var pngSource = readPNG(from + '/' + imageName);  
        for (n in Reflect.fields(frames)) {
            var frameData = Reflect.field(frames, n); 
            var frameRect = Reflect.field(frameData, 'frame'); 
            var frameX = Reflect.field(frameRect, 'x');
            var frameY = Reflect.field(frameRect, 'y');
            var frameW = Reflect.field(frameRect, 'w');
            var frameH = Reflect.field(frameRect, 'h'); 
            var toFile = to + "/" + n + "." + "png"; 
            /*if (verbose == "true") {
                Lib.println("Saving: " + toFile);
            }*/
        }     
    }
    
    private function doXmlUnpack(file:String):Void
    {
        // TODO: implement
    }
    
    private function doJsonToXmlConversion(file:String):Void
    {
        var fromFile = file;
        var fileName = file.substr(from.length + 1, file.lastIndexOf(".") - (from.length + 1));
        var toFile = to + "/" + fileName + "." + "xml";        
        var s = File.getContent(fromFile);
        var data = Json.parse(s);        
        if (verbose == "true") {
            Lib.println("Processing: " + file);
        }
        var frames = Reflect.field(data, 'frames');
        var meta = Reflect.field(data, 'meta');
        var imageName = Reflect.field(meta, 'image');        
        var resultHeader = '<?xml version="1.0" encoding="UTF-8"?>\n<TextureAtlas imagePath="' + imageName + '">\n';
        var resultFooter = '\n</TextureAtlas>';
        var result = '';
        for (n in Reflect.fields(frames)) {
            var frameData = Reflect.field(frames, n); 
            var frameRect = Reflect.field(frameData, 'frame'); 
            var frameX = Reflect.field(frameRect, 'x');
            var frameY = Reflect.field(frameRect, 'y');
            var frameW = Reflect.field(frameRect, 'w');
            var frameH = Reflect.field(frameRect, 'h');
            result += '  <SubTexture name="' + n + '" x="' + frameX + '" y="' + frameY + '" width="' + frameW + '" height="'+frameH + '"/>\n';
        }         
        if (verbose == "true") {
            Lib.println("Saving: " + toFile);
        }
        var o = File.write(toFile, true);
        o.writeString(resultHeader + result + resultFooter);
        o.close();
    }
    
    private function doXmlToJsonConversion(file:String):Void
    {
        var fromFile = file;
        var fileName = file.substr(from.length + 1, file.lastIndexOf(".") - (from.length + 1));
        var toFile = to + "/" + fileName + "." + "json";

        var s = File.getContent(fromFile);

        if (verbose == "true") {
            Lib.println("Processing: " + file);
        }
        if(!Utf8.validate(s)) {
            // Convert UTF-16 (UCS2) to UTF-8
            var arr = s.split("");
            var filtered = "";
            var c = 0;
            for(p in arr) {
                /*if(c < 10) {
                    Lib.println(p + ": " + s.charCodeAt(c));                    
                }*/
                if(s.charCodeAt(c) > 0 && s.charCodeAt(c) < 254) {
                    filtered += p;
                }
                c++;
            }
            s = filtered;
        }
        if(s.indexOf("SubTexture") == -1) {
            if (verbose == "true") {
                Lib.println("Ignoring ('SubTexture' not found): " + file);
                return;
            }
        }

        /* -----------------------------------------------------------*/
        // normalize the XML string
        if(s.indexOf("<TextureAtlas") > 0) {
            s = StringTools.replace(s, s.substr(0, s.indexOf("<TextureAtlas")), "");
        }
        var si = 0;
        var ei = 1;
        while(si > -1 && ei > -1 && si != ei) {
            //s = StringTools.trim(s);
            si = s.indexOf("<!--");
            ei = s.indexOf("-->");
            var part = s.substr(si, ei + 1);
            if(part != null && part != "" && part.length > 1) {
                //Lib.println("Removing segment: " + "'" + part + "'" + " (size:" + part.length + ")");
                s = StringTools.replace(s, part, "");
            }
        }
        s = StringTools.trim(s);
        var xml = Xml.parse(s);
        var project = xml.firstChild();
        var imagePath = project.get("imagePath");
        if(imagePath == null || imagePath == "") {
            if (verbose == "true") {
                Lib.println("Ignoring ('imagePath' not found): " + file);
            }
            return;
        }
        if(autoImagePath == "true") {
            imagePath = fileName + ".png";
        }
        // get png size
        var pngData = {"width": 0, "height": 0};
        var pngPath = from + "/" + imagePath;
        if(FileSystem.exists(pngPath)) {
            /*if (verbose == "true") {
                Lib.println("Reading PNG: " + pngPath);
            }*/
            pngData = readPNG(pngPath);
        }

        /* -----------------------------------------------------------*/
        // create the json core structure
        var json = {
            "frames": {},
            "meta": {
                "app": "TexturePacker",
                "version": "1.0",
                "image": imagePath,
                "format": "RGBA8888",
                "size": { "w": pngData.width, "h": pngData.height},
                "scale": 1
            }
        };

        // parse frames
        var frameCount = 0;
        for (node in project)
        {
            if (node.nodeType == Xml.Element)
            {
                var stN = node.get("name");
                stN = Std.string(stN).split(" ").join("_");
                if(autoFrameName == "true") {
                    stN = Std.string(frameCount);
                }
                var stX = Std.parseFloat(node.get("x"));
                var stY = Std.parseFloat(node.get("y"));
                var stW = Std.parseFloat(node.get("width"));
                var stH = Std.parseFloat(node.get("height"));
                var o = {
                    "frame": {"x": stX, "y": stY, "w": stW, "h": stH},
                    "rotated": false,
                    "trimmed": false,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": stW, "h": stH},
                    "sourceSize": {"w": stW, "h": stH},
                };
                Reflect.setField(json.frames, stN, o);
                frameCount++;
            }
        }

        /* -----------------------------------------------------------*/
        // beautify output optionally
        if (format == "true") {
            s = Json.stringify(json, null, "  ");
        } else {
            s = Json.stringify(json);
        }

        /* -----------------------------------------------------------*/
        // write out file      
        if (verbose == "true") {
            Lib.println("Saving: " + toFile);
        }
        var o = File.write(toFile, true);
        o.writeString(s);
        o.close();

        /* -----------------------------------------------------------*/
        // use for testing on a single file
        //Sys.exit(1);
    }

    private function readPNG(file:String):{data:Bytes, width:Int, height:Int} {
        var handle = File.read(file, true);
        var d = new Reader(handle).read();
        var hdr = Tools.getHeader(d);
        var ret = {
            data:Tools.extract32(d),
            width:hdr.width,
            height:hdr.height
        };
        handle.close();
        return ret;
    }

    private function parseArgs():Bool
    {
        // Parse args
        var args = Sys.args();
        for (i in 0...args.length) {
            if (Lambda.has(argKeys, args[i].substr(1))) {
                Reflect.setField(argValues, args[i].substr(1), args[i + 1]);
                Reflect.setField(this, args[i].substr(1), args[i + 1]);
            }
        }
        // Print out parsed arguments in verbose mode
        if (verbose == "true") {
            Lib.println(argValues);
        }
        // Check to see if argument is missing
        if (to == null) { Lib.println("Missing argument '-to'"); return false; }
        if (from == null) { Lib.println("Missing argument '-from'"); return false; }
        if (ext == null) { Lib.println("Missing argument '-ext'"); return false; }

        return true;
    }

    public function recurse(path:String)
    {
        var dir = FileSystem.readDirectory(path);
        for (item in dir)
        {
            var s = path + "/" + item;
            if (FileSystem.isDirectory(s))
            {
                recurse(s);
            }
            else
            {
                var exts = [ext];
                if(Lambda.has(exts, getExt(item)))
                    items.push(s);
            }
        }
    }

    public function getExt(s:String)
    {
        return s.substr(s.lastIndexOf(".") + 1).toLowerCase();
    }

    public function removeDirectory(d, p = null)
    {
        if (p == null) p = d;
        if (verbose == "true") {
            Lib.println("Removing folder: " + d);
        }
        var dir = FileSystem.readDirectory(d);
        for (item in dir)
        {
            item = p + "/" + item;
            if (FileSystem.isDirectory(item)) {
                removeDirectory(item);
            }else{
                FileSystem.deleteFile(item);
            }
        }
        FileSystem.deleteDirectory(d);
    }
}
