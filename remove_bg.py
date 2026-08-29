from PIL import Image
import sys

def remove_background(input_path, output_path, tolerance=50):
    img = Image.open(input_path).convert("RGBA")
    datas = img.getdata()
    
    # Assume top-left pixel is the background color
    bg_color = datas[0]
    
    new_data = []
    for item in datas:
        # Check if color is close to background
        if (abs(item[0] - bg_color[0]) < tolerance and
            abs(item[1] - bg_color[1]) < tolerance and
            abs(item[2] - bg_color[2]) < tolerance):
            # Change to transparent
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    img.save(output_path, "PNG")
    print(f"Background removed. Saved to {output_path}")

if __name__ == "__main__":
    remove_background("assets/logo.png", "assets/logo_transparent.png")
