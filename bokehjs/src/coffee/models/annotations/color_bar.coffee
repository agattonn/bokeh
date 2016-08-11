_ = require "underscore"

Annotation = require "./annotation"
BasicTicker = require "../tickers/basic_ticker"
BasicTickFormatter = require "../formatters/basic_tick_formatter"
LinearColorMapper = require "../mappers/linear_color_mapper"
LinearMapper = require "../mappers/linear_mapper"
LogMapper = require "../mappers/log_mapper"
Range1d = require "../ranges/range1d"
SidePanel = require "../../core/layout/side_panel"

p = require "../../core/properties"
text_util = require "../../core/util/text"

SHORT_DIM = 25
LONG_DIM_MIN_SCALAR = 0.3
LONG_DIM_MAX_SCALAR = 0.8

class ColorBarView extends Annotation.View
  initialize: (options) ->
    super(options)
    @_set_canvas_image()

  _get_panel_offset: () ->
    # ColorBars draw from the top down, so set the y_panel_offset to _top
    x = @model.panel._left._value
    y = @model.panel._top._value
    return {x: x, y: -y}

  _get_size: () ->
    label_extent = @_get_label_extent()
    major_tick_out = @model.major_tick_out
    label_standoff = @model.label_standoff

    switch @model.orientation
      when "vertical"
        image_size = if @model.legend_width == 'auto' then SHORT_DIM else @model.legend_width
        size = image_size + major_tick_out + label_standoff + label_extent + 2 * @model.legend_padding
      when "horizontal"
        image_size = if @model.legend_height == 'auto' then SHORT_DIM else @model.legend_height
        size = image_size + @mget('title_height') + major_tick_out + label_standoff + label_extent + 2 * @model.legend_padding

    return size

  _set_canvas_image: () ->
    palette = @model.color_mapper.palette

    switch @model.orientation
      when "vertical" then [w, h] = [1, palette.length]
      when "horizontal" then [w, h] = [palette.length, 1]

    canvas = document.createElement('canvas')
    [canvas.width, canvas.height] = [w, h]
    image_ctx = canvas.getContext('2d')
    image_data = image_ctx.getImageData(0, 0, w, h)

    # We always want to draw the entire palette linearly, so we create a new
    # LinearColorMapper instance and map a monotonic range of values with
    # length = palette.length to get each palette color in order.
    cmap = new LinearColorMapper.Model({palette: palette})
    buf = cmap.v_map_screen([0...palette.length])
    buf8 = new Uint8ClampedArray(buf)
    image_data.data.set(buf8)
    image_ctx.putImageData(image_data, 0, 0)

    @image = canvas

  compute_legend_bbox: () ->
    legend_margin = @model.legend_margin
    legend_padding = @model.legend_padding
    label_standoff =  @model.label_standoff
    major_tick_out = @model.major_tick_out
    title_height = @mget('title_height')

    image_dimensions = @mget('computed_image_dimensions')
    image_height = image_dimensions.height
    image_width = image_dimensions.width

    label_extent = @_get_label_extent()

    if @model.orientation == "vertical"
      legend_height = image_height + title_height + legend_padding * 2
      legend_width = image_width + major_tick_out + label_standoff + label_extent + legend_padding * 2

    else
      legend_height = image_height + title_height + major_tick_out + label_standoff + label_extent + legend_padding * 2
      legend_width = image_width + legend_padding * 2

    location = @model.location
    h_range = @plot_view.frame.get('h_range')
    v_range = @plot_view.frame.get('v_range')

    if _.isString(location)
      switch location
        when 'top_left'
          x = h_range.get('start') + legend_margin
          y = v_range.get('end') - legend_margin
        when 'top_center'
          x = (h_range.get('end') + h_range.get('start'))/2 - legend_width/2
          y = v_range.get('end') - legend_margin
        when 'top_right'
          x = h_range.get('end') - legend_margin - legend_width
          y = v_range.get('end') - legend_margin
        when 'right_center'
          x = h_range.get('end') - legend_margin - legend_width
          y = (v_range.get('end') + v_range.get('start'))/2 + legend_height/2
        when 'bottom_right'
          x = h_range.get('end') - legend_margin - legend_width
          y = v_range.get('start') + legend_margin + legend_height
        when 'bottom_center'
          x = (h_range.get('end') + h_range.get('start'))/2 - legend_width/2
          y = v_range.get('start') + legend_margin + legend_height
        when 'bottom_left'
          x = h_range.get('start') + legend_margin
          y = v_range.get('start') + legend_margin + legend_height
        when 'left_center'
          x = h_range.get('start') + legend_margin
          y = (v_range.get('end') + v_range.get('start'))/2 + legend_height/2
        when 'center'
          x = (h_range.get('end') + h_range.get('start'))/2 - legend_width/2
          y = (v_range.get('end') + v_range.get('start'))/2 + legend_height/2
    else if _.isArray(location) and location.length == 2
      [x, y] = location

    sx = @plot_view.canvas.vx_to_sx(x)
    sy = @plot_view.canvas.vy_to_sy(y)

    image_sx = sx + legend_padding
    image_sy = sy + legend_padding + title_height

    return {sx: sx, sy: sy, image_sx: image_sx, image_sy: image_sy, width: legend_width, height: legend_height, image_width: image_width, image_height: image_height}

  render: () ->
    if @model.visible == false
      return

    ctx = @plot_view.canvas_view.ctx
    ctx.save()

    if @model.panel?
      panel_offset = @_get_panel_offset()
      ctx.translate(panel_offset.x, panel_offset.y)
      frame_offset = @_get_frame_offset()
      ctx.translate(frame_offset.x, frame_offset.y)

    @_draw_bbox(ctx)
    @_draw_image(ctx)
    @_draw_major_ticks(ctx)
    @_draw_minor_ticks(ctx)
    @_draw_major_labels(ctx)
    if @model.title
      @_draw_title(ctx)
    ctx.restore()

  _draw_bbox: (ctx) ->
    geom = @compute_legend_bbox()
    ctx.save()
    if @visuals.background_fill.doit
      @visuals.background_fill.set_value(ctx)
      ctx.fillRect(geom.sx, geom.sy, geom.width, geom.height)
    if @visuals.border_line.doit
      @visuals.border_line.set_value(ctx)
      ctx.strokeRect(geom.sx, geom.sy, geom.width, geom.height)
    ctx.restore()

  _draw_image: (ctx) ->
    geom = @compute_legend_bbox()

    ctx.save()
    ctx.setImageSmoothingEnabled(false)
    ctx.drawImage(@image, geom.image_sx, geom.image_sy, geom.image_width, geom.image_height)
    if @visuals.scale_line.doit
        @visuals.scale_line.set_value(ctx)
        ctx.strokeRect(geom.image_sx, geom.image_sy, geom.image_width, geom.image_height)
    ctx.restore()

  _draw_major_ticks: (ctx) ->
    if not @visuals.major_tick_line.doit
      return

    geom = @compute_legend_bbox()
    coords = @mget('tick_coordinates').major

    [sx, sy] = [coords[0], coords[1]]
    [nx, ny] = @mget('normals')

    tin = @model.major_tick_in
    tout = @model.major_tick_out

    [x_offset, y_offset] = [geom.image_sx + geom.image_width * nx, geom.image_sy + geom.image_height * ny]

    ctx.save()
    ctx.translate(x_offset, y_offset)
    @visuals.major_tick_line.set_value(ctx)
    for i in [0...sx.length]
      ctx.beginPath()
      ctx.moveTo(Math.round(sx[i]+nx*tout), Math.round(sy[i]+ny*tout))
      ctx.lineTo(Math.round(sx[i]-nx*tin), Math.round(sy[i]-ny*tin))
      ctx.stroke()
    ctx.restore()

  _draw_minor_ticks: (ctx) ->
    if not @visuals.minor_tick_line.doit
      return

    geom = @compute_legend_bbox()
    coords = @mget('tick_coordinates').minor

    [sx, sy] = [coords[0], coords[1]]
    [nx, ny] = @mget('normals')

    tin = @model.minor_tick_in
    tout = @model.minor_tick_out

    [x_offset, y_offset] = [geom.image_sx + geom.image_width * nx, geom.image_sy + geom.image_height * ny]

    ctx.save()
    ctx.translate(x_offset, y_offset)
    @visuals.minor_tick_line.set_value(ctx)
    for i in [0...sx.length]
      ctx.beginPath()
      ctx.moveTo(Math.round(sx[i]+nx*tout), Math.round(sy[i]+ny*tout))
      ctx.lineTo(Math.round(sx[i]-nx*tin), Math.round(sy[i]-ny*tin))
      ctx.stroke()
    ctx.restore()

  _draw_major_labels: (ctx) ->
    if not @visuals.major_label_text.doit
      return

    geom = @compute_legend_bbox()
    coords = @mget('tick_coordinates').major

    [sx, sy] = [coords[0], coords[1]]
    [nx, ny] = @mget('normals')

    [x_offset, y_offset] = [geom.image_sx + geom.image_width * nx, geom.image_sy + geom.image_height * ny]

    standoff = (@model.label_standoff + @model.major_tick_out)
    [x_standoff, y_standoff] = [standoff*nx, standoff*ny]

    labels = @mget('tick_coordinates').major_labels
    labels = @mget('formatter').doFormat(labels)

    @visuals.major_label_text.set_value(ctx)

    ctx.save()
    ctx.translate(x_offset + x_standoff, y_offset + y_standoff)
    for i in [0...sx.length]
      ctx.fillText(labels[i],
                   Math.round(sx[i]+nx*@model.label_standoff),
                   Math.round(sy[i]+ny*@model.label_standoff))
    ctx.restore()

  _draw_title: (ctx) ->
    if not @visuals.title_text.doit
      return

    geom = @compute_legend_bbox()
    ctx.save()
    @visuals.title_text.set_value(ctx)
    ctx.fillText(@model.title, geom.image_sx, geom.image_sy - @model.title_standoff)
    ctx.restore()

  _get_label_extent: () ->
    ctx = @plot_view.canvas_view.ctx
    ctx.save()
    @visuals.major_label_text.set_value(ctx)

    switch @model.orientation
      when "vertical"
        formatted_labels = @model.formatter.doFormat(@mget('tick_coordinates').major_labels)
        label_extent = _.max((ctx.measureText(label.toString()).width for label in formatted_labels))
      when "horizontal"
        label_extent = text_util.get_text_height(@visuals.major_label_text.font_value()).height

    ctx.restore()
    return label_extent

  _get_frame_offset: () ->
    [xoff, yoff] = [0, 0]
    panel = @model.panel
    frame = @plot_view.frame

    switch panel.side
      when "left", "right" then yoff = Math.abs(panel.get("top") - frame.get("top"))
      when "above", "below" then xoff = Math.abs(frame.get("left"))

    return {x: xoff, y: yoff}

class ColorBar extends Annotation.Model
  default_view: ColorBarView
  type: 'ColorBar'

  @mixins [
      'text:major_label_',
      'text:title_',
      'line:major_tick_',
      'line:minor_tick_',
      'line:border_',
      'line:scale_',
      'fill:background_',
  ]

  @define {
      location:       [ p.Any,            'top_right' ]
      orientation:    [ p.Orientation,    'vertical'  ]
      title:          [ p.String,                     ]
      title_standoff: [ p.Number,         2           ]
      legend_height:  [ p.Any,            'auto'      ]
      legend_width:   [ p.Any,            'auto'      ]
      ticker:         [ p.Instance,    () -> new BasicTicker.Model()         ]
      formatter:      [ p.Instance,    () -> new BasicTickFormatter.Model()  ]
      color_mapper:   [ p.Instance                    ]
      label_standoff: [ p.Number,         5           ]
      legend_margin:  [ p.Number,         30          ]
      legend_padding: [ p.Number,         10          ]
      major_tick_in:  [ p.Number,         2           ]
      major_tick_out: [ p.Number,         6           ]
      minor_tick_in:  [ p.Number,         0           ]
      minor_tick_out: [ p.Number,         4           ]
  }

  @override {
      background_fill_color: "#ffffff"
      background_fill_alpha: 0.95
      border_line_color: "#e5e5e5"
      border_line_alpha: 0.5
      major_label_text_align: "center"
      major_label_text_baseline: "middle"
      major_label_text_font_size: "8pt"
  }

  initialize: (attrs, options) ->
    super(attrs, options)

    @define_computed_property('normals', @_normals, true)

    @define_computed_property('title_height', @_title_height, true)
    # @add_dependencies('title_height', this, ['title_text_font', 'title_text_font_size', 'title_text_font_style', 'title', 'title_standoff'])

    @define_computed_property('computed_image_dimensions', @_computed_image_dimensions, false)
    # @add_dependencies('computed_image_dimensions', this, ['legend_width', 'legend_height', 'orientation', 'title_height'])
    # @add_dependencies('computed_image_dimensions', @get('plot'), ['height', 'width'])

    # @define_computed_property('tick_coordinate_mapper', @_tick_coordinate_mapper, true)
    # @add_dependencies('tick_coordinate_mapper', this, ['computed_image_dimensions'])

    @define_computed_property('tick_coordinates', @_tick_coordinates, false)
    @add_dependencies('tick_coordinates', this, ['tick_coordinate_mapper', 'normals'])

  _normals: () ->
    if @.orientation == 'vertical'
      [i, j] = [1, 0]
    else
      [i, j] = [0, 1]
    return [i, j]

  _title_height: () ->
    font_value = @.title_text_font + " " + @.title_text_font_size + " " + @.title_text_font_style
    title_height = if @.title then text_util.get_text_height(font_value).height + @.title_standoff else 0
    return title_height

  _computed_image_dimensions: () ->
    ###
    Heuristics to determine ColorBar image dimensions if set to "auto"

    Note: Returns the height/width values for the ColorBar's scale image, not
    the dimensions of the entire ColorBar.

    If the short dimension (the width of a vertical bar or height of a
    horizontal bar) is set to "auto", the resulting dimension will be set to
    25 px.

    For a ColorBar in a side panel with the long dimension (the height of a
    vertical bar or width of a horizontal bar) set to "auto", the
    resulting dimension will be as long as the adjacent frame edge, so that the
    bar "fits" to the plot.

    For a ColorBar in the plot frame with the long dimension set to "auto", the
    resulting dimension will be the greater of:
      * The length of the color palette * 25px
      * The parallel plot dimension * 0.30
        (i.e the plot height for a vertical ColorBar)
    But not greater than:
      * The parallel plot dimension * 0.80
    ###

    frame_height = @plot.plot_canvas.frame.get('height')
    frame_width = @plot.plot_canvas.frame.get('width')

    switch @orientation
      when "vertical"
        if @legend_height == 'auto'
          if @panel?
            # height = @plot.plot_canvas.frame.get('height') - 2 * @legend_padding - @get('title_height')
            height = frame_height - 2 * @legend_padding - @get('title_height')
          else
            height = _.max([@color_mapper.palette.length * SHORT_DIM,
                            frame_height * LONG_DIM_MIN_SCALAR])
            height = _.min([height,
                            frame_height * LONG_DIM_MAX_SCALAR - 2 * @legend_padding - @get('title_height')])
        else
          height = @legend_height

        width = if @legend_width == 'auto' then SHORT_DIM else @legend_width

      when "horizontal"
        height = if @legend_height == 'auto' then SHORT_DIM else @legend_height

        if @legend_width == 'auto'
          if @panel?
            width = frame_width - 2 * @legend_padding
          else
            width = _.max([@color_mapper.palette.length * SHORT_DIM,
                           frame_width * LONG_DIM_MIN_SCALAR])
            width = _.min([width,
                           frame_width * LONG_DIM_MAX_SCALAR - 2 * @legend_padding])
        else
          width = @legend_width

    return {"height": height, "width": width}

  _tick_coordinate_mapper: (target_range_end) ->
    ###
    Creates and returns a mapper instance that maps the `color_mapper` range
    (low to high) to a screen space range equal to the length of the ColorBar's
    scale image. The mapper is used to calculate the tick coordinates in screen
    coordinates for plotting purposes.

    Note: the type of color_mapper has to match the type of mapper (i.e.
    a LinearColorMapper will require a corresponding LinearMapper instance).
    ###

    # scale_dimensions = @get("computed_image_dimensions")
    #
    # switch @.orientation
    #   when "vertical" then target_range_end = scale_dimensions.height
    #   when "horizontal" then target_range_end = scale_dimensions.width

    mapping = {
      'source_range': new Range1d.Model({
        start: @.color_mapper.low
        end: @.color_mapper.high
      })
      'target_range': new Range1d.Model({
        start: 0
        end: target_range_end})
    }

    switch @.color_mapper.type
      when "LinearColorMapper" then mapper = new LinearMapper.Model(mapping)
      when "LogColorMapper" then mapper = new LogMapper.Model(mapping)

    return mapper

  _tick_coordinates: () ->

    dimensions = @get('computed_image_dimensions')
    switch @orientation
      when "vertical" then target_range_end = dimensions.height
      when "horizontal" then target_range_end = dimensions.width

    mapper = @_tick_coordinate_mapper(target_range_end)

    [i, j] = @get('normals')

    [start, end] = [@.color_mapper.low, @.color_mapper.high]

    ticks = @.ticker.get_ticks(start, end, null, @.ticker.desired_num_ticks)

    majors = ticks.major
    minors = ticks.minor

    major_coords = [[], []]
    minor_coords = [[], []]

    for ii in [0...majors.length]
      if majors[ii] < start or majors[ii] > end
        continue
      major_coords[i].push(majors[ii])
      major_coords[j].push(0)

    # [major_min, major_max] = [_.min(major_coords[i]), _.max(major_coords[i])]

    for ii in [0...minors.length]
      if minors[ii] < start or minors[ii] > end
        continue
      minor_coords[i].push(minors[ii])
      minor_coords[j].push(0)

    major_labels = major_coords[i]

    major_coords[0] = mapper.v_map_to_target(major_coords[0])
    major_coords[1] = mapper.v_map_to_target(major_coords[1])

    minor_coords[0] = mapper.v_map_to_target(minor_coords[0])
    minor_coords[1] = mapper.v_map_to_target(minor_coords[1])

    return {
      "major": major_coords
      "minor": minor_coords
      "major_labels": major_labels
    }

module.exports =
  Model: ColorBar
  View: ColorBarView