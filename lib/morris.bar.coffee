class Morris.Bar extends Morris.Grid
  constructor: (options) ->
    return new Morris.Bar(options) unless (@ instanceof Morris.Bar)
    super($.extend {}, options, parseTime: false)

  init: ->
    @cumulative = @options.stacked

    if @options.hideHover isnt 'always'
      @hover = new Morris.Hover(parent: @el)
      @on('hovermove', @onHoverMove)
      @on('hoverout', @onHoverOut)
      @on('gridclick', @onGridClick)

  # Default configuration
  #
  defaults:
    barSizeRatio: 0.75
    barGap: 3
    barColors: [
      '#0b62a4'
      '#7a92a3'
      '#4da74d'
      '#afd8f8'
      '#edc240'
      '#cb4b4b'
      '#9440ed'
    ]
    xLabelMargin: 50

  # Do any size-related calculations
  #
  # @private
  calc: ->
    @calcBars()
    if @options.hideHover is false
      @hover.update(@hoverContentForRow(@data.length - 1)...)

  # calculate series data bars coordinates and sizes
  #
  # @private
  calcBars: ->
    for row, idx in @data
      row._x = @left + @width * (idx + 0.5) / @data.length
      row._y = for y in row.y
        if y? then @transY(y) else null

  # Draws the bar chart.
  #
  draw: ->
    @drawXAxis() if @options.axes in [true, 'both', 'x']
    @drawYAxisCaption() if @options.yCaption?
    @drawSeries()

  # draw the x-axis labels
  #
  # @private
  drawXAxis: ->
    # draw x axis labels
    ypos = @bottom + (@options.xAxisLabelTopPadding || @options.padding / 2)
    prevLabelMargin = null
    prevAngleMargin = null
    for i in [0...@data.length]
      row = @data[@data.length - 1 - i]
      label = @drawXAxisLabel(row._x, ypos, row.label)
      textBox = label.getBBox()
      label.transform("r#{-@options.xLabelAngle}")
      labelBox = label.getBBox()
      label.transform("t0,#{labelBox.height / 2}...")
      if @options.xLabelAngle != 0
        offset = -0.5 * textBox.width *
          Math.cos(@options.xLabelAngle * Math.PI / 180.0)
        label.transform("t#{offset},0...")
      # try to avoid overlaps
      if (not prevLabelMargin? or
          prevLabelMargin >= labelBox.x + labelBox.width or
          prevAngleMargin? and prevAngleMargin >= labelBox.x) and
         labelBox.x >= 0 and (labelBox.x + labelBox.width) < @el.width()
        if @options.xLabelAngle != 0
          margin = 1.25 * @options.gridTextSize /
            Math.sin(@options.xLabelAngle * Math.PI / 180.0)
          prevAngleMargin = labelBox.x - margin
        prevLabelMargin = labelBox.x - @options.xLabelMargin
      else
        label.remove()

  # draw the data series
  #
  # @private
  drawSeries: ->
    groupWidth = @width / @options.data.length
    numBars = if @options.stacked? then 1 else @options.ykeys.length
    barWidth = (groupWidth * @options.barSizeRatio - @options.barGap * (numBars - 1)) / numBars
    leftPadding = groupWidth * (1 - @options.barSizeRatio) / 2
    zeroPos = if @ymin <= 0 and @ymax >= 0 then @transY(0) else null
    @bars = for row, idx in @data
      lastTop = 0
      for ypos, sidx in row._y
        if ypos != null
          if zeroPos
            top = Math.min(ypos, zeroPos)
            bottom = Math.max(ypos, zeroPos)
          else
            top = ypos
            bottom = @bottom

          left = @left + idx * groupWidth + leftPadding
          left += sidx * (barWidth + @options.barGap) unless @options.stacked
          size = bottom - top

          if @options.verticalGrid and @options.verticalGrid.condition(row.x)
            @drawBar(left - leftPadding, @top, groupWidth, Math.abs(@top - @bottom), @options.verticalGrid.color, @options.verticalGrid.opacity)

          if opts = @options?.staticLabels
            @drawXAxisLabel(left + barWidth / 2, top - (opts.margin or 0), @labelContentForRow(idx), opts.color, opts.size)

          top -= lastTop if @options.stacked
          @drawBar(left, top, barWidth, size, @colorFor(row, sidx, 'bar'), @options.barStyle?.opacity, @options.barStyle?.radius)

          lastTop += size
        else
          null

  # @private
  #
  # @param row  [Object] row data
  # @param sidx [Number] series index
  # @param type [String] "bar", "hover" or "label"
  colorFor: (row, sidx, type) ->
    if typeof @options.barColors is 'function'
      r = { x: row.x, y: row.y[sidx], label: row.label }
      s = { index: sidx, key: @options.ykeys[sidx], label: @options.labels[sidx] }
      @options.barColors.call(@, r, s, type)
    else
      @options.barColors[sidx % @options.barColors.length]

  # hit test - returns the index of the row at the given x-coordinate
  #
  hitTest: (x, y) ->
    return null if @data?.length is 0 or x <= @left or x > @left + @width
    x = Math.max(Math.min(x, @right - @options.padding), @left + @options.padding)
    Math.min(@data.length - 1, Math.floor((x - @left) / (@width / @data.length)))

  # click on grid event handler
  #
  # @private
  onGridClick: (x, y) =>
    if (index = @hitTest(x, y))?
      @fire 'click', index, @options.data[index], x, y

  # hover movement event handler
  #
  # @private
  onHoverMove: (x, y) =>
    if (index = @hitTest(x, y))?
      console.log('index=',index)
      @hover.update(@hoverContentForRow(index, x, y)...)

  # hover out event handler
  #
  # @private
  onHoverOut: =>
    if @options.hideHover isnt false
      @hover.hide()

  # hover content for a point
  #
  # @private
  hoverContentForRow: (index, eventX, eventY) ->
    res = []
    row = @data[index]
    content = "<div class='morris-hover-row-label'>#{row.label}</div>"
    for y, j in row.y
      content += """
        <div class='morris-hover-point' style='color: #{@colorFor(row, j, 'label')}'>
          #{@options.labels[j]}:
          #{@yLabelFormat(y)}
        </div>
      """
    if typeof @options.hoverCallback is 'function'
      content = @options.hoverCallback(index, @options, content)
    res.push content
    switch @options.stickyHover
      when 'pointer'
        res.push [eventX + 30, eventY + 60]...
      when 'bar'
        # TODO: remove addressing @data directyl
        padding = @width / @data.length * (1 - @options.barSizeRatio) / 2
        left = @left + index * @width / @data.length
        right = left + @width / @data.length
        top = @data[index]._y[0]
        bottom = @bottom
        res.push [@normalize(eventX, left + padding, right - padding),@normalize(eventY, top, bottom)]...
      when 'corner'
        res.push [@right, 0]...
      else
        x = @left + (index + 0.5) * @width / @data.length
        res.push x
    res

  normalize: (value, min, max) ->
    res = if min < value < max
       value
    else
      if value > max then max else min
    res

  labelContentForRow: (index) ->
    row = @data[index]
    content = ''
    for y, j in row.y
      content += "#{@options.labels[j]}:#{@yLabelFormat(y)} "
    if typeof @options.staticLabels.labelCallback is 'function'
      content = @options.staticLabels.labelCallback(index, @options, content)
    content

  drawXAxisLabel: (xPos, yPos, text, fColor = @options.gridTextColor, fSize = @options.gridTextSize, fFamily = @options.gridTextFamily, fWeight = @options.gridTextWeight) ->
    label = @raphael.text(xPos, yPos, text)
      .attr('font-size', fSize)
      .attr('font-family', fFamily)
      .attr('font-weight', fWeight)
      .attr('fill', fColor)

  drawYAxisCaption: ->
    leftPosition = @left - @options.padding / 2 + @options.yCaption.offsetX
    verticalMiddle = (@bottom - @top) / 2
    @drawXAxisLabel(leftPosition, verticalMiddle, @options.yCaption.text, @options.yCaption.color, @options.yCaption.fSize, @options.yCaption.fFamily,@options.yCaption.fWeight)
      .transform('r-90')

  drawBar: (xPos, yPos, width, height, barColor, opacity = '1', radius = [0,0,0,0]) ->
    if Math.max(radius...) > height or (r for r in radius when r is 0).length is 4
      path = @raphael.rect(xPos, yPos, width, height)
    else
      path = @raphael.path @roundedRect(xPos, yPos, width, height, radius)
    path
      .attr('fill', barColor)
      .attr('stroke-width', 0)
      .attr('fill-opacity', opacity)

  roundedRect: (x, y, w, h, r = [0,0,0,0]) ->
    [].
    concat(["M", x, r[0] + y, "Q", x, y, x + r[0], y]).
    concat(["L", x + w - r[1], y, "Q", x + w, y, x + w, y + r[1]]).
    concat(["L", x + w, y + h - r[2], "Q", x + w, y + h, x + w - r[2], y + h]).
    concat(["L", x + r[3], y + h, "Q", x, y + h, x, y + h - r[3], "Z"])

