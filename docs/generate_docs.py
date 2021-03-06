#!/usr/bin/env python3

import json
import sys
import os


def html_escape(s):
    return s.encode('ascii', 'xmlcharrefreplace').decode('utf8')

##------------------------------------------------------------------------------
## generate_page
##------------------------------------------------------------------------------
def generate_page(nodes, nodetype):
    html = r'''<!DOCTYPE html>
<html>
<head>
    <link rel="stylesheet" type="text/css" href="auraglyph-fonts.css">
    <link rel="stylesheet" type="text/css" href="auraglyph-doc.css" />
    <link rel="stylesheet" type="text/css" href="auraglyph-dark.css" />
</head>
<body>
    
    <a name="top"/>
    <div id="title">
        <div class="titleL"><h1><a href="index.html">Auraglyph Node Reference</a></h1></div>
    </div>
    
    <div id="body">
{menu}
        <div class="toc"><a id="toc"/>
{toc}
        </div>

        <div class="summary"><a id="summary"/>
{summary}
        </div>

        <div class="nodes">
{nodes}
        </div>
    </div>
</body>
</html>
'''
    title = 'Nodes'
    node_html = ''
    menu = generate_menu(['audio', 'control'], nodetype)
    toc = generate_toc(nodes)
    summary = generate_summary(nodetype, nodes)
    for node in nodes:
        node_html += generate_node(node, nodetype)
    return html.format(title=title, nodes=node_html, toc=toc, menu=menu, summary=summary)


##------------------------------------------------------------------------------
## process_info
##------------------------------------------------------------------------------
def process_info_to_html(info, p_attr=""):
    # get lines
    lines = info.splitlines()
    # filter non-empty lines
    lines = filter(lambda l: len(l)>0, info.splitlines())
    # format in <p>'s
    if p_attr:
        p_tag = "<p {attr}>".format(attr=p_attr)
    else:
        p_tag = "<p>"
    lines_html = ["{p_tag}{txt}</p>".format(p_tag=p_tag, txt=l) for l in lines]
    # join with newlines
    return "\n".join(lines_html)


##------------------------------------------------------------------------------
## generate_menu
##------------------------------------------------------------------------------
def generate_menu(node_types, selected):
    html = r'''
        <div id="top_menu">
            <div class="container">
                {items}
            </div>
            {info}
            <p class="description">Click on a node's icon below to learn more about its functionality. </p>
        </div>
'''
    item_html = r'''<div class="item"><a href="{url}">{name}</a></div>'''
    selected_html = r'''<div class="item selected">{name}</div>'''
    info_file_path = selected+'.txt'
    if os.path.exists(info_file_path):
        with open(info_file_path, "r") as f:
            info_html = process_info_to_html(f.read(), 'class="description"')
    items = ''
    for node_type in node_types:
        if node_type == selected:
            items += selected_html.format(name=node_type)
        else:
            items += item_html.format(name=node_type, url=node_type+'.html')
    return html.format(items=items, info=info_html)

##------------------------------------------------------------------------------
## generate_toc
##------------------------------------------------------------------------------
def generate_toc(nodes):
    toc_item = r'''            <p class="toc_node"><a href="#{node}" class="typename">{node}</a></p>
'''
    toc = ''
    for node in nodes:
        toc += toc_item.format(node=node["name"])
    return toc

##------------------------------------------------------------------------------
## generate_summary
##------------------------------------------------------------------------------
def generate_summary(nodetype, nodes):
    html = r'''
        <div id="node_summary">
            <div class="container">
                {items}
            </div>
        </div>
'''
    item_tmpl = r'''<a href="#{name}">
    <div class="node_summary_item">
    {icon}
    {label}
    </div>
</a>'''
    label_tmpl = r'''<p class="node_summary_item_text">{text}</p>'''
    items = []
    size_to_scale = 0.25/100
    size = 80
    for node in nodes:
        node_symbol = generate_node_symbol(node["icon"], nodetype, 
            size=str(size)+"px", scale=str(size*size_to_scale))
        label_html = label_tmpl.format(text=node["name"])
        item_html = item_tmpl.format(icon=node_symbol, name=node["name"], label=label_html)
        items.append(item_html)

    return html.format(items="\n".join(items))


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
            <!--<hr />-->
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
    tmpl = r'''
                <div class="node_header">
                    <div class="node_symbol" width="5em" height="5em">
{node_symbol}
                    </div>
                    <div class="node_header_info">
                        <h2 class="node_title" name="{node_name}">{node_name}</h2>
                        <p class="node_desc">{node_desc}</p>
                    </div>
                </div>
'''
    size_to_scale = 0.25/100
    size = 60
    node_symbol = generate_node_symbol(node["icon"], nodetype, str(size)+"px", str(size*size_to_scale))
    node_name = node["name"]
    node_desc = html_escape(node["desc"])
    return tmpl.format(node_symbol=node_symbol, 
                       node_name=node_name, 
                       node_desc=node_desc)

##------------------------------------------------------------------------------
## generate_node_symbol
##------------------------------------------------------------------------------
def generate_node_symbol(icon, nodetype, size="5em", scale="0.125"):
    tmpl = r'''
<svg width="{size}" height="{size}" transform="">
{icon_base}
{icon_geo}
</svg>
'''
    if node_type == 'audio':
        icon_base = generate_audio_node_base(scale)
    elif node_type == 'control':
        icon_base = generate_control_node_base(scale)
    
    if icon["type"] == "line_strip":
        icon_geo = generate_line_strip(icon["geo"], scale)
    elif icon["type"] == "lines":
        icon_geo = generate_lines(icon["geo"], scale)
    elif icon["type"] == "line_loop":
        icon_geo = generate_line_loop(icon["geo"], scale)
    else:
        icon_geo = ""
    return tmpl.format(icon_base=icon_base, icon_geo=icon_geo, size=size)

##------------------------------------------------------------------------------
## generate_control_node_base
##------------------------------------------------------------------------------
def generate_control_node_base(scale="0.125"):
#     html = r'''    <rect x="-50" y="-50" width="500" height="500" fill="#0C1021" stroke="none" transform="scale({scale})"/>
#     <rect x="16" y="16" width="368" height="368" stroke="#F9BB02" fill="none" stroke-width="10" transform="scale({scale})"/>
# '''
    tmpl = r'''    <rect x="16" y="16" width="368" height="368" stroke="#F9BB02" fill="none" stroke-width="10" transform="scale({scale})"/>
'''
    return tmpl.format(scale=scale)

##------------------------------------------------------------------------------
## generate_audio_node_base
##------------------------------------------------------------------------------
def generate_audio_node_base(scale="0.125"):
#     html = r'''    <circle cx="200" cy="200" r="250" fill="#0C1021" stroke="none" transform="scale({scale})"/>
#     <circle cx="200" cy="200" r="184" stroke="#F9BB02" fill="none" stroke-width="10" transform="scale({scale})"/>
# '''
    tmpl = r'''    <circle cx="200" cy="200" r="184" stroke="#F9BB02" fill="none" stroke-width="10" transform="scale({scale})"/>
'''
    return tmpl.format(scale=scale)

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
def generate_lines(geo, scale="0.125"):
    svg = r'''    <polyline points="{points}" 
stroke="#F9BB02" fill="none" stroke-width="10" 
transform="scale({scale})" />
'''
    lines = ''
    for i in range(int(len(geo)/2)):
        point0 = filter_point(geo[i*2])
        point1 = filter_point(geo[i*2+1])
        points = "{x0},{y0} {x1},{y1}".format(x0=point0["x"], y0=point0["y"],
                                              x1=point1["x"], y1=point1["y"])
        lines += svg.format(points=points, scale=scale)
    return lines

##------------------------------------------------------------------------------
## generate_line_strip
##------------------------------------------------------------------------------
def generate_line_strip(geo, scale="0.125"):
    svg = r'''    <polyline points="{points}" 
stroke="#F9BB02" fill="none" stroke-width="10" 
transform="scale({scale})" />'''
    points = ''
    for point in geo:
        point = filter_point(point)
        points += "{x},{y} ".format(x=point["x"], y=point["y"])
    return svg.format(points=points, scale=scale)

##------------------------------------------------------------------------------
## generate_line_strip
##------------------------------------------------------------------------------
def generate_line_loop(geo, scale="0.125"):
    svg = r'''    <polyline points="{points}" 
stroke="#F9BB02" fill="none" stroke-width="10" 
transform="scale({scale})" />'''
    points = ''
    for point in geo:
        point = filter_point(point)
        points += "{x},{y} ".format(x=point["x"], y=point["y"])
    if len(geo):
        # re-add first point to end of loop
        point = filter_point(geo[0])
        points += "{x},{y} ".format(x=point["x"], y=point["y"])
    return svg.format(points=points, scale=scale)

##------------------------------------------------------------------------------
## generate_node_members
##------------------------------------------------------------------------------
def generate_node_members(members, type):
    tmpl = r'''            <h3 class="node_section_header">{member_type}s</h3>
            <div class="members {member_type}s">
{node_members}
            </div>
'''
    node_members = ''
    for member in members:
        node_members += generate_node_member(member, type)
    return tmpl.format(node_members=node_members, member_type=type)

##------------------------------------------------------------------------------
## generate_node_member
##------------------------------------------------------------------------------
def generate_node_member(member, type):
    tmpl = r'''
                <div class="member input">
                    <p class="member_name {member_type}_name">{member_name}</p>
                    <p class="member_desc {member_type}_desc">{member_desc}</p>
                </div>
'''
    return tmpl.format(member_name=member["name"], 
                       member_desc=html_escape(member["desc"]), 
                       member_type=type)

nodes = json.load(sys.stdin)
node_type = sys.argv[1]

html = generate_page(nodes[node_type.lower()], node_type)

sys.stdout.write(html)

