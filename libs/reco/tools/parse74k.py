#!/usr/bin/env python3

import re
import sys
import os
import string
import json


folder_in = sys.argv[1]
folder_out = sys.argv[2]

idx = list(string.digits) + list(string.ascii_uppercase) + ['_'+a for a in list(string.ascii_lowercase)]

def num2cat(num):
    return idx[num-1]

def last(path):
    return os.path.split(path)[-1]

def html_top():
    html = r'''<html>
<head>
    <style type="text/css">
        body {
            font-family: Palatino;
        }
        
        hr {
            border: 4px solid #333;
        }
        
        h2 {
            color: #333;
            font-size: 64px;
            margin-left: 0.5em;
            margin-bottom: 0.1em;
        }
        
        .pts svg {
            background: #EEE;
            width: 10em;
            height: 10em;
        }

        .pts svg * {
            transform: scale(0.25);
        }
    </style>
</head>
<body>
'''
    return html

def html_bottom():
    html = r'''</body>
</html>
'''
    return html

def html_category_top(cat_name):
    html = r'''<div class="cat">
    <h2>Category: {cat_name}</h3>
    <hr />
    <div class="pts">
'''
    return html.format(cat_name=cat_name)

def html_category_bottom():
    html = r'''    </div>
</div>
'''
    return html

def svg_pts(pts_array):
    svg = r'''        <svg>
{polylines}        </svg>
''' 
    polyline = r'''            <polyline points="{pts}" stroke="#000000" fill="none" stroke-width="10" transform="" /> 
'''
    polylines = ''
    for pts in pts_array:
        xys = ''
        for pt in pts:
            xys += "{x},{y} ".format(x=pt[0], y=pt[1])
        polylines += polyline.format(pts=xys)
    return svg.format(polylines=polylines)

def parse_arrays(text):
    nums_array = []
    matches = re.findall(r'\[([^\]]+)\];', text)
    if matches:
        for match in matches:
            nums = []
            fields = re.split('\s+', match)
            for field in fields:
                if field:
                    nums.append(float(field))
            nums_array.append(nums)
    else:
        sys.stderr.write('parse error\n')
        raise Exception()
    return nums_array

def get_pts(filepath):
    with open(filepath, 'r') as f:
        text = f.read()
        re_row = r'rows = {([^}]+)};'
        match_row = re.search(re_row, text)
        re_col = r'cols = {([^}]+)};'
        match_col = re.search(re_col, text)
        if match_row and match_col:
            nums_array_row = parse_arrays(match_row[1])
            nums_array_col = parse_arrays(match_col[1])
            if len(nums_array_row) != len(nums_array_col):
                sys.stderr.write('parse error\n')
                raise Exception()
            pts_array = []
            for i in range(len(nums_array_row)):
                pts = []
                nums_row = nums_array_row[i]
                nums_col = nums_array_col[i]
                if len(nums_row) != len(nums_col):
                    sys.stderr.write('parse error\n')
                    raise Exception()
                for j in range(len(nums_row)):
                    pt = (nums_col[j], nums_row[j])
                    pts.append(pt)
                pts_array.append(pts)
            return pts_array
        else:
            sys.stderr.write('parse error\n')
            raise Exception()

def put_pts(pts, filepath):
    # print html/svg
    with open(filepath, 'w') as f:
        f.write(json.dumps(pts))

def do_example(input_filepath, output_filepath):
    # print("-- ex %s -> %s" % (last(input_filepath), last(output_filepath)))
    pts = get_pts(input_filepath)
    put_pts(pts, output_filepath)
    print(svg_pts(pts))

def do_category(cat_name, input_folder, output_folder):
    # print("- cat %s -> %s" % (last(input_folder), last(output_folder)))
    print(html_category_top(cat_name))
    os.makedirs(output_folder, exist_ok=True)
    ex_num = 0
    for f_ex in os.listdir(input_folder):
        if os.path.splitext(f_ex)[1] == '.m':
            example_in = os.path.join(input_folder, f_ex)
            ex_out_name = "cat{cat}_ex{ex}.json".format(cat=cat_name, ex=ex_num)
            example_out = os.path.join(output_folder, ex_out_name)
            do_example(example_in, example_out)
            ex_num += 1
    print(html_category_bottom())

def do_folder(input_folder, output_folder):
    print(html_top())
    os.makedirs(output_folder, exist_ok=True)
    for f_cat in os.listdir(input_folder):
        match = re.match(r'''Sample(\d+)''', f_cat)
        if match:
            cat_num = int(match[1])
            cat_name = num2cat(cat_num)
            category_in = os.path.join(input_folder, f_cat)
            category_out = os.path.join(output_folder, cat_name)
            do_category(cat_name, category_in, category_out)
    print(html_bottom())

if not os.path.isabs(folder_in):
    folder_in = os.path.abspath(folder_in)
if not os.path.isabs(folder_out):
    folder_out = os.path.abspath(folder_out)

do_folder(folder_in, folder_out)

