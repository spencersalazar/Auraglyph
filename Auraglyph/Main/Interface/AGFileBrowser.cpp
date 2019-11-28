//
//  AGFileBrowser.mm
//  Auragraph
//
//  Created by Spencer Salazar on 1/7/17.
//  Copyright © 2017 Spencer Salazar. All rights reserved.
//

#include "AGFileBrowser.h"
#include "AGStyle.h"
#include "Animation.h"
#include "AGFileManager.h"
#include "AGGenericShader.h"


#define USE_TEST_PATHS 0


AGFileBrowser::AGFileBrowser(const GLvertex3f &position)
{
    m_xScale = lincurvef(AGStyle::open_animTimeX, AGStyle::open_squeezeHeight, 1);
    m_yScale = lincurvef(AGStyle::open_animTimeY, AGStyle::open_squeezeHeight, 1);
    
    m_pos = position;
    m_size.x = 250;
    m_size.y = m_size.x/AGStyle::aspect16_9;
    
    TexFont *font = AGStyle::standardFont64();
    m_itemHeight = font->height();
    m_fontScale = AGStyle::standardFontScale*0.8f;
    
    m_verticalScrollPos.clampTo(0, 0);
    
#if USE_TEST_PATHS
    m_paths = {
        "SF_BeatC100-01.wav SF_BeatC100-01.wav SF_BeatC100-01.wav SF_BeatC100-01.wav",
        "SF_BeatC100-02.wav SF_BeatC100-01.wav SF_BeatC100-01.wav SF_BeatC100-01.wav",
        "SF_BeatC100-03.wav SF_BeatC100-01.wav SF_BeatC100-01.wav SF_BeatC100-01.wav",
        "SF_BeatC100-04.wav SF_BeatC100-01.wav SF_BeatC100-01.wav SF_BeatC100-01.wav",
        "SF_BeatC100-05.wav",
        "SF_BeatC100-06.wav",
        "SF_BeatC100-07.wav",
        "SF_BeatC100-08.wav",
        "SF_BeatCfx100-01.wav",
        "SF_BeatCfx100-02.wav",
        "SF_BeatCfx100-03.wav",
        "SF_BeatCfx100-04.wav",
        "SF_BeatCfx100-05.wav",
        "SF_BeatCfx100-06.wav",
        "SF_BeatCfx100-07.wav",
        "SF_BeatCfx100-08.wav",
        "SF_BeatD100-01.wav",
        "SF_BeatD100-02.wav",
        "SF_BeatD100-03.wav",
        "SF_BeatD100-04.wav",
        "SF_BeatD100-05.wav",
        "SF_BeatD100-06.wav",
        "SF_BeatD100-07.wav",
        "SF_BeatD100-08.wav",
        "SF_BeatDfx100-01.wav",
        "SF_BeatDfx100-02.wav",
        "SF_BeatDfx100-03.wav",
        "SF_BeatDfx100-04.wav",
        "SF_BeatDfx100-05.wav",
        "SF_BeatDfx100-06.wav",
        "SF_BeatDfx100-07.wav",
        "SF_BeatDfx100-08.wav",
    };
#endif // USE_TEST_PATHS
}

AGFileBrowser::~AGFileBrowser()
{
}

void AGFileBrowser::update(float t, float dt)
{
    AGInteractiveObject::update(t, dt);
    
    if(parent())
    {
        m_renderState.modelview = parent()->m_renderState.modelview;
        m_renderState.projection = parent()->m_renderState.projection;
    }
    else
    {
        m_renderState.modelview = globalModelViewMatrix();
        m_renderState.projection = projectionMatrix();
    }
    
    m_renderState.modelview = GLKMatrix4Translate(m_renderState.modelview, m_pos.x, m_pos.y, m_pos.z);
    
    if(m_yScale <= AGStyle::open_squeezeHeight) m_xScale.update(dt);
    if(m_xScale >= 0.99f) m_yScale.update(dt);
    
    m_renderState.modelview = GLKMatrix4Scale(m_renderState.modelview,
                                              m_yScale <= AGStyle::open_squeezeHeight ? (float)m_xScale : 1.0f,
                                              m_xScale >= 0.99f ? (float)m_yScale : AGStyle::open_squeezeHeight,
                                              1);
}

void AGFileBrowser::render()
{
    // draw inner box
    AGStyle::frameBackgroundColor().set();
    drawTriangleFan((GLvertex3f[]){
        { -m_size.x/2, -m_size.y/2, 0 },
        {  m_size.x/2, -m_size.y/2, 0 },
        {  m_size.x/2,  m_size.y/2, 0 },
        { -m_size.x/2,  m_size.y/2, 0 },
    }, 4);
    
    // draw outer frame
    AGStyle::foregroundColor().set();
    glLineWidth(4.0f);
    drawLineLoop((GLvertex3f[]){
        { -m_size.x/2, -m_size.y/2, 0 },
        {  m_size.x/2, -m_size.y/2, 0 },
        {  m_size.x/2,  m_size.y/2, 0 },
        { -m_size.x/2,  m_size.y/2, 0 },
    }, 4);
    
    GLKMatrix4 clipMatrix = m_renderState.modelview;
    GLvrectf clipRect;
    clipRect.bl = GLvertex3f(-m_size.x/2, -m_size.y/2, 0);
    clipRect.ur = GLvertex3f(m_size.x/2, m_size.y/2, 0);

    TexFont *font = AGStyle::standardFont64();
    float textHeight = font->height()*m_fontScale;
    int i = 0;
    for(string path : m_paths) {
        GLKMatrix4 modelView = m_renderState.modelview;
        float yPos = m_verticalScrollPos + m_size.y/2*0.95-m_itemHeight*(i+1)+m_itemHeight/2.0;
        
        GLcolor4f textColor;
        
        if(i == m_selection) {
            GLKMatrix4 xform = GLKMatrix4MakeTranslation(0, yPos, 0);
            float margin = 0.975f;
            // draw selection box
            glVertexAttrib4fv(AGVertexAttribColor, (const GLfloat *) &AGStyle::foregroundColor());
            
            drawTriangleFan((GLvertex3f[]){
                { -m_size.x/2*margin,  m_itemHeight/2*margin, 0 },
                { -m_size.x/2*margin, -m_itemHeight/2*margin, 0 },
                {  m_size.x/2*margin, -m_itemHeight/2*margin, 0 },
                {  m_size.x/2*margin,  m_itemHeight/2*margin, 0 },
            }, 4, xform);
            
            textColor = AGStyle::frameBackgroundColor();
        } else {
            textColor = AGStyle::foregroundColor();
        }
        
        // move to bottom left corner of box
        modelView = GLKMatrix4Translate(modelView, -m_size.x/2*0.9f, yPos-textHeight*2.0/3.0f, 0);
        modelView = GLKMatrix4Scale(modelView, m_fontScale, m_fontScale, 1);
        
        font->render(path, textColor, modelView, m_renderState.projection,
                     true, clipMatrix, clipRect);
        
        i++;
    }
    
    if (m_paths.size() == 0) {
        // no files
        vector<string> msg = {
            "no files found.",
            "try adding files using",
            "iTunes file sharing.",
        };
        
        Matrix4 modelView = m_renderState.modelview;
        float lineHeight = textHeight*1.2f;
        float yPos = msg.size()*lineHeight/2-textHeight;
        
        for (auto& line : msg) {
            float lineWidth = font->width(line)*m_fontScale;
            float xPos = -lineWidth/2;
            font->render(line, AGStyle::foregroundColor(),
                         modelView.translate(xPos, yPos, 0).scale(m_fontScale),
                         m_renderState.projection);
            yPos -= lineHeight;
        }
    }
    
    AGInteractiveObject::render();
}

void AGFileBrowser::renderOut()
{
    m_xScale = lincurvef(AGStyle::open_animTimeX/2, 1, AGStyle::open_squeezeHeight);
    m_yScale = lincurvef(AGStyle::open_animTimeY/2, 1, AGStyle::open_squeezeHeight);
}

bool AGFileBrowser::finishedRenderingOut() const
{
    return m_xScale <= AGStyle::open_squeezeHeight;
}

void AGFileBrowser::touchDown(const AGTouchInfo &t)
{
    GLvertex3f relPos = t.position-m_pos;
    // float yPos = m_size.y/2*0.9+m_verticalScrollPos;
    
    for(int i = 0; i < m_paths.size(); i++)
    {
        float yPos = m_verticalScrollPos + m_size.y/2*0.95-m_itemHeight*(i+1)+m_itemHeight/2.0;
        
        dbgprint("AGFileBrowser::bbox top: %f bot: %f lft: %f rgt: %f\n",
                 yPos+m_itemHeight/2.0f, yPos-m_itemHeight/2.0f,
                 -m_size.x/2, m_size.x/2);
        dbgprint("AGFileBrowser::relPos: %f,%f\n", relPos.x, relPos.y);
        
        if(relPos.y < yPos+m_itemHeight/2.0f && relPos.y > yPos-m_itemHeight/2.0f &&
           relPos.x > -m_size.x/2 && relPos.x < m_size.x/2)
        {
            m_selection = i;
            dbgprint("AGFileBrowser::m_selection: %i\n", m_selection);
            break;
        }
        
//        yPos -= m_itemStart;
    }
    
    m_touchStart = t.position;
    m_lastTouch = t.position;
}

void AGFileBrowser::touchMove(const AGTouchInfo &t)
{
    if((m_touchStart-t.position).magnitudeSquared() > AGStyle::maxTravel*AGStyle::maxTravel)
    {
        m_selection = -1;
        // start scrolling
        m_verticalScrollPos += (t.position.y - m_lastTouch.y);
        dbgprint("AGFileBrowser::m_verticalScrollPos: %f\n", (float)m_verticalScrollPos);
    }
    
    m_lastTouch = t.position;
}

void AGFileBrowser::touchUp(const AGTouchInfo &t)
{
    if((m_touchStart-t.position).magnitudeSquared() > AGStyle::maxTravel*AGStyle::maxTravel)
    {
        m_selection = -1;
    }
    
    if(m_selection >= 0)
    {
        dbgprint("AGFileBrowser::choose: %i\n", m_selection);
        
        m_choose(m_paths[m_selection]);
    }
}

void AGFileBrowser::setSize(const GLvertex2f &size)
{
    m_size = size;
}

GLvertex2f AGFileBrowser::size()
{
    return m_size;
}

void AGFileBrowser::setDirectoryPath(const string &directoryPath)
{
#if !USE_TEST_PATHS
    vector<string> paths = AGFileManager::instance().listDirectory(directoryPath);
    for(string path : paths)
    {
        if(m_filter(path))
            m_paths.push_back(path);
    }
#endif // !USE_TEST_PATHS
    
    m_verticalScrollPos.clampTo(0, max(0.0f, m_paths.size()*m_itemHeight-m_size.y*0.95f));
}

string AGFileBrowser::selectedFile() const
{
    return m_file;
}

void AGFileBrowser::onChooseFile(const std::function<void (const string &)> &choose)
{
    m_choose = choose;
}

void AGFileBrowser::onCancel(const std::function<void (void)> &cancel)
{
    m_cancel = cancel;
}

/*
 Filter function takes filepath as an argument and returns whether or not
 to display that file.
 */
void AGFileBrowser::setFilter(const std::function<bool (const string &)> &filter)
{
    m_filter = filter;
}

