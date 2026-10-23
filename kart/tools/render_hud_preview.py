#!/usr/bin/env python3
"""Render a check_hud --export-graph JSON using Pillow, never a Roblox screenshot.

The renderer uses the actual GUI hierarchy, transforms, labels, native vector
shapes, strokes, corners and gradients. Fonts/antialiasing approximate Studio.
Requires Pillow only for this optional visual check, not the kart or test suite.
"""
import argparse
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

parser=argparse.ArgumentParser()
parser.add_argument('graph',type=Path)
parser.add_argument('output',type=Path)
args=parser.parse_args()
records=json.loads(args.graph.read_text())
by_id={i+1:row for i,row in enumerate(records)}
children={}
for ident,row in by_id.items():children.setdefault(row.get('parent'),[]).append((ident,row))
S=2; WIDTH=1040; HEIGHT=330
canvas=Image.new('RGBA',(WIDTH*S,(HEIGHT+30)*S),(37,42,47,255))
font_path='/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf'

def rgb(value,alpha=1):
 value=value or {'R':1,'G':1,'B':1}
 return tuple(max(0,min(255,round(value[key]*255))) for key in ('R','G','B'))+(max(0,min(255,round(alpha*255))),)

def multiply(a,b):
 aa,ab,ac,ad,atx,aty=a; ba,bb,bc,bd,btx,bty=b
 return (aa*ba+ac*bb,ab*ba+ad*bb,aa*bc+ac*bd,ab*bc+ad*bd,aa*btx+ac*bty+atx,ab*btx+ad*bty+aty)

identity=(1,0,0,1,0,0)
cache={}
def layout(ident):
 if ident in cache:return cache[ident]
 row=by_id[ident]; parent=row.get('parent')
 if parent in by_id:
  pm,pw,ph,pvis=layout(parent)
 else:pm,pw,ph,pvis=identity,WIDTH,HEIGHT,True
 if row['ClassName'] not in ('Frame','TextLabel'):
  result=pm,pw,ph,pvis and row.get('Enabled',True)
  cache[ident]=result;return result
 size=row.get('Size',{});pos=row.get('Position',{});anchor=row.get('AnchorPoint',{})
 w=size.get('sx',0)*pw+size.get('ox',0);h=size.get('sy',0)*ph+size.get('oy',0)
 x=pos.get('sx',0)*pw+pos.get('ox',0)-anchor.get('X',0)*w
 y=pos.get('sy',0)*ph+pos.get('oy',0)-anchor.get('Y',0)*h
 theta=math.radians(row.get('Rotation',0));c=math.cos(theta);s=math.sin(theta)
 local=(c,s,-s,c,x+w/2-c*w/2+s*h/2,y+h/2-s*w/2-c*h/2)
 result=multiply(pm,local),w,h,pvis and row.get('Visible',True)
 cache[ident]=result;return result

def draw_layer(local,transform):
 a,b,c,d,tx,ty=transform
 det=a*d-b*c
 inverse=(d/det,-c/det,(c*ty-d*tx)/det*S,-b/det,a/det,(b*tx-a*ty)/det*S)
 warped=local.transform(canvas.size,Image.Transform.AFFINE,inverse,resample=Image.Resampling.BICUBIC)
 canvas.alpha_composite(warped)

def own_children(ident,cls):return [row for _,row in children.get(ident,[]) if row['ClassName']==cls]
for ident,row in sorted(by_id.items(),key=lambda item:(item[1].get('ZIndex',1),item[0])):
 if row['ClassName'] not in ('Frame','TextLabel'):continue
 transform,w,h,visible=layout(ident)
 if not visible or w<=0 or h<=0:continue
 iw=max(1,math.ceil(w*S));ih=max(1,math.ceil(h*S))
 local=Image.new('RGBA',(iw,ih),(0,0,0,0));draw=ImageDraw.Draw(local)
 corners=own_children(ident,'UICorner');radius=0
 if corners:
  corner=corners[-1]['CornerRadius'];radius=min(w,h)*corner.get('scale',0)+corner.get('offset',0)
 radius=min(radius,min(w,h)/2)*S
 mask=Image.new('L',(iw,ih),0);md=ImageDraw.Draw(mask)
 md.rounded_rectangle((0,0,iw-1,ih-1),radius=radius,fill=255)
 alpha=1-row.get('BackgroundTransparency',0)
 if row['ClassName']=='TextLabel':alpha=1-row.get('BackgroundTransparency',0)
 if alpha>0:
  gradients=own_children(ident,'UIGradient')
  if gradients:
   grad=gradients[-1]; colors=grad['Color'];first,last=colors[0],colors[-1]
   if isinstance(first,list):first=first[1];last=last[1]
   c0=rgb(first);c1=rgb(last)
   background=Image.new('RGBA',(iw,ih));pixels=background.load()
   theta=math.radians(grad.get('Rotation',0));dx=math.cos(theta);dy=math.sin(theta)
   extent=abs(dx)*iw+abs(dy)*ih
   base=rgb(row.get('BackgroundColor3'))
   for yy in range(ih):
    for xx in range(iw):
     t=max(0,min(1,0.5+((xx-iw/2)*dx+(yy-ih/2)*dy)/max(extent,1)))
     pixels[xx,yy]=tuple(round((c0[k]+(c1[k]-c0[k])*t)*base[k]/255) for k in range(3))+(round(alpha*255),)
  else:background=Image.new('RGBA',(iw,ih),rgb(row.get('BackgroundColor3'),alpha))
  background.putalpha(mask.point(lambda v:round(v*alpha)))
  local.alpha_composite(background)
 for border in own_children(ident,'UIStroke'):
  opacity=1-border.get('Transparency',0)
  if opacity<=0:continue
  width=max(1,round(border.get('Thickness',1)*S))
  draw.rounded_rectangle((width/2,width/2,iw-1-width/2,ih-1-width/2),radius=max(0,radius-width/2),outline=rgb(border.get('Color'),opacity),width=width)
 if row['ClassName']=='TextLabel':
  font=ImageFont.truetype(font_path,max(1,round(row.get('TextSize',14)*S)))
  align=row.get('TextXAlignment','Center')
  x=0 if align=='Left' else iw if align=='Right' else iw/2
  anchor='lm' if align=='Left' else 'rm' if align=='Right' else 'mm'
  stroke_width=round(S*(1-row.get('TextStrokeTransparency',1)))
  draw.text((x,ih/2),row.get('Text',''),font=font,fill=rgb(row.get('TextColor3')),anchor=anchor,stroke_width=stroke_width,stroke_fill=rgb(row.get('TextStrokeColor3')))
 draw_layer(local,transform)
footer=ImageDraw.Draw(canvas)
font=ImageFont.truetype(font_path,10*S)
footer.text((12*S,346*S),'SOURCE-DRIVEN GUI PREVIEW  •  Sample race values  •  Native Roblox UI layout; font/rendering approximated outside Studio',font=font,fill=(164,179,188,255),anchor='lm')
args.output.parent.mkdir(parents=True,exist_ok=True)
canvas.convert('RGB').save(args.output)
print('Rendered actual HUD scene graph:',args.output)
