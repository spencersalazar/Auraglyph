#!/usr/bin/env python3

import json
import sys

##------------------------------------------------------------------------------
## generate_page
##------------------------------------------------------------------------------
def generate_page(nodes, nodetype):
    html = r'''<html>
<head>
    <link rel="stylesheet" type="text/css" href="auraglyph-doc.css" />
</head>
<body>
    
    <a name="top"/>
    <div id="title">
        <div class="titleL"><h1><a href="index.html">Auraglyph Reference</a></h1></div>
        <div class="titleR"><h1>{title}</h1></div>
    </div>
    
    <div id="body">
        <div class="toc"><a id="toc"/>
        </div>

        <div class="nodes">
{nodes}
        </div>
    </div>
</body>
</html>
    '''
    title = '{nodetype} Nodes'.format(nodetype=nodetype.title())
    node_html = ''
    for node in nodes:
        node_html += generate_node(node, nodetype)
    return html.format(title=title, nodes=node_html)

##------------------------------------------------------------------------------
## generate_node
##------------------------------------------------------------------------------
def generate_node(node, nodetype):
    html = r'''
            <a name="{node_name}" />
            <div class="node">
{node_header}
{node_inputs}
{node_params}
{node_outputs}
            <p class="top_link">[ <a href="#top">top</a> ]</p>
            </div>
            <hr />
'''
    node_header = generate_node_header(node, nodetype)
    node_inputs = generate_node_members(node['ports'], 'input')
    node_params = generate_node_members(node['params'], 'param')
    node_outputs = generate_node_members(node['outputs'], 'output')
    # node_outputs = generate_node_outputs(node)
    return html.format(node_name=node["name"], node_header=node_header, 
                       node_inputs=node_inputs, node_params=node_params, 
                       node_outputs=node_outputs)

##------------------------------------------------------------------------------
## generate_node_header
##------------------------------------------------------------------------------
def generate_node_header(node, nodetype):
    html = r'''
<div class="node_header">
    <div class="node_symbol" width="5em" height="5em">
{node_symbol}
    </div>
    <h2 class="node_title" name="{node_name}">{node_name}</h2>
    <p class="node_desc"><p>{node_desc}</p>
</div>
'''
    node_symbol = generate_node_symbol(node["icon"], nodetype)
    node_name = node["name"]
    node_desc = node["desc"]
    return html.format(node_symbol=node_symbol, 
                       node_name=node_name, 
                       node_desc=node_desc)

##------------------------------------------------------------------------------
## generate_node_symbol
##------------------------------------------------------------------------------
def generate_node_symbol(icon, nodetype):
    html = r'''
<svg width="5em" height="5em" transform="">
{icon_base}
{icon_geo}
</svg>
'''
    if node_type == 'audio':
        icon_base = generate_audio_node_base()
    elif node_type == 'control':
        icon_base = generate_control_node_base()
    
    if icon["type"] == "line_strip":
        icon_geo = generate_line_strip(icon["geo"])
    elif icon["type"] == "lines":
        icon_geo = generate_lines(icon["geo"])
    elif icon["type"] == "line_loop":
        icon_geo = generate_line_loop(icon["geo"])
    else:
        icon_geo = ""
    return html.format(icon_base=icon_base, icon_geo=icon_geo)

##------------------------------------------------------------------------------
## generate_control_node_base
##------------------------------------------------------------------------------
def generate_control_node_base():
    html = r'''    <rect x="-50" y="-50" width="500" height="500" fill="#000038" stroke="none" transform="scale(0.125)"/>
    <rect x="16" y="16" width="368" height="368" stroke="#F9BB02" fill="none" stroke-width="10" transform="scale(0.125)"/>
'''
    return html

##------------------------------------------------------------------------------
## generate_audio_node_base
##------------------------------------------------------------------------------
def generate_audio_node_base():
    html = r'''    <circle cx="200" cy="200" r="250" fill="#000038" stroke="none" transform="scale(0.125)"/>
    <circle cx="200" cy="200" r="184" stroke="#F9BB02" fill="none" stroke-width="10" transform="scale(0.125)"/>
'''
    return html

##------------------------------------------------------------------------------
## filter_point
##------------------------------------------------------------------------------
def filter_point(point):
    ICON_SCALE=(4,-4)
    ICON_OFFSET=(200,200)
    return dict(x=ICON_OFFSET[0]+ICON_SCALE[0]*float(point["x"]), 
                y=ICON_OFFSET[1]+ICON_SCALE[1]*float(point["y"]))

##------------------------------------------------------------------------------
## generate_lines
##------------------------------------------------------------------------------
def generate_lines(geo):
    svg = r'''    <polyline points="{points}" \
stroke="#F9BB02" fill="none" stroke-width="10" \
transform="scale(0.125)" />
'''
    lines = ''
    for i in range(int(len(geo)/2)):
        point0 = filter_point(geo[i*2])
        point1 = filter_point(geo[i*2+1])
        points = "{x0},{y0} {x1},{y1}".format(x0=point0["x"], y0=point0["y"],
                                              x1=point1["x"], y1=point1["y"])
        lines += svg.format(points=points)
    return lines

##------------------------------------------------------------------------------
## generate_line_strip
##------------------------------------------------------------------------------
def generate_line_strip(geo):
    svg = r'''    <polyline points="{points}" \
stroke="#F9BB02" fill="none" stroke-width="10" \
transform="scale(0.125)" />'''
    points = ''
    for point in geo:
        point = filter_point(point)
        points += "{x},{y} ".format(x=point["x"], y=point["y"])
    return svg.format(points=points)

##------------------------------------------------------------------------------
## generate_line_strip
##------------------------------------------------------------------------------
def generate_line_loop(geo):
    svg = r'''    <polyline points="{points}" \
stroke="#F9BB02" fill="none" stroke-width="10" \
transform="scale(0.125)" />'''
    points = ''
    for point in geo:
        point = filter_point(point)
        points += "{x},{y} ".format(x=point["x"], y=point["y"])
    if len(geo):
        # re-add first point to end of loop
        point = filter_point(geo[0])
        points += "{x},{y} ".format(x=point["x"], y=point["y"])
    return svg.format(points=points)

##------------------------------------------------------------------------------
## generate_node_members
##------------------------------------------------------------------------------
def generate_node_members(members, type):
    html = r'''            <h3 class="node_section_header">{member_type}s</h3>
            <div class="members {member_type}s">
{node_members}
            </div>
'''
    node_members = ''
    for member in members:
        node_members += generate_node_member(member, type)
    return html.format(node_members=node_members, member_type=type)

##------------------------------------------------------------------------------
## generate_node_member
##------------------------------------------------------------------------------
def generate_node_member(member, type):
    html = r'''
                <div class="member input">
                    <p class="member_name {member_type}_name">{member_name}</p>
                    <p class="member_desc {member_type}_desc">{member_desc}</p>
                </div>
'''
    return html.format(member_name=member["name"], member_desc=member["desc"], 
                       member_type=type)

nodes = json.load(sys.stdin)
node_type = sys.argv[1]

html = generate_page(nodes[node_type.lower()], node_type)

sys.stdout.write(html)

