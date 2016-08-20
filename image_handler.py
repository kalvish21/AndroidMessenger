
from PIL import Image


def resize_image(image_size, filename):
    # Resize the image with given dimensions
    try:
        im = Image.open(local_path)
        im.thumbnail(image_size, Image.ANTIALIAS)
        im.save(filename, "PNG")
    except Exception, e:
        print e


class MacApp(object):
    image_arr = {
        "-16.png": 16,
        "-16@2x.png": 16 * 2,
        "-32.png": 32,
        "-32@2x.png": 32 * 2,
        "-128.png": 11286,
        "-128@2x.png": 128 * 2,
        "-256.png": 256,
        "-256@2x.png": 256 * 2,
        "-512.png": 512,
        "-512@2x.png": 512 * 2,
    }
    local_path = "chat.png"
    name = "icon"    

    def start(self):
        for img in image_arr.keys():
            resize_image((image_arr[img],image_arr[img]), "%s%s" % (name, img))


class AndroidApp(object):
    image_arr = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    local_path = "chat.png"
    name = "chat.png"    

    def start(self):
        for img in image_arr.keys():
            resize_image((image_arr[img],image_arr[img]), "%s/%s" % (img, name))

