class Morris.Area extends Morris.Line
  # Initialise
  #
  areaDefaults =
    fillOpacity: 'auto'
    behaveLikeLine: false
    smooth: true

  constructor: (options) ->
    return new Morris.Area(options) unless (@ instanceof Morris.Area)
    areaOptions = $.extend {}, areaDefaults, options

    @cumulative = not areaOptions.behaveLikeLine

    if areaOptions.fillOpacity is 'auto'
      areaOptions.fillOpacity = if areaOptions.behaveLikeLine then .8 else 1

    super(areaOptions)

  # calculate series data point coordinates
  #
  # @private
  calcPoints: ->
    return super() if @options.behaveLikeLine
    for row in @data
      row._x = @transX(row.x)
      total = 0
      row._y = for y in row.y
        total += (y || 0)
        @transY(total)
      row._ymax = Math.max row._y...

  # draw the data series
  #
  # @private
  drawSeries: ->
    @seriesPoints = []
    if @options.behaveLikeLine
      range = [0..@options.ykeys.length-1]
    else
      range = [@options.ykeys.length-1..0]

    @generateFilledPaths()
    for i in range
      @_drawFillFor i
      @_drawLineFor i
      @_drawPointFor i

  _drawFillFor: (index) ->
    path = @fillings[index]
    if path isnt null
      path = path + "L#{@transX(@xmax)},#{@bottom}L#{@transX(@xmin)},#{@bottom}Z"
      @drawFilledPath path, @fillForSeries(index)

  flatten = (array) ->
    flat = []
    for item in array
      if Object::toString.call(item) is "[object Array]"
        flat.push.apply flat, item
      else
        flat.push item
    flat

  generateFilledPaths: ->
    @fillings = for i in [0...@options.ykeys.length]
      smooth = if typeof @options.smooth is "boolean" then @options.smooth else @options.ykeys[i] in @options.smooth
      console.log('filled smooth is ', smooth)
      coords = (
        for r, index in @data
          res = []
          previousY = @data[index - 1] and @data[index - 1].y[i]
          console.log(previousY)
          if not previousY and not @options.continuousLine
            res.push
              x: r._x - 0.001, y: @bottom
          if r.y[i]
            res.push
              x: r._x, y: r._y[i]
            res
          else

            previousX = @data[index - 1] and @data[index - 1]._x || @left
            console.log('previousX ', previousX)
            unless @options.continuousLine
              console.log('creating shit, lol')
              {x: previousX, y: @bottom}
        )
      console.log('coords #1: ', coords)
      coords = flatten(coords)
      console.log('coords #2: ', coords)
      coords = (c for c in coords when c)

      if coords.length > 1
        console.log(coords)
        Morris.Line.createPath coords, smooth, @bottom
      else
        null

  fillForSeries: (i) ->
    color = Raphael.rgb2hsl @colorFor(@data[i], i, 'line')
    Raphael.hsl(
      color.h,
      if @options.behaveLikeLine then color.s * 0.9 else color.s * 0.75,
      Math.min(0.98, if @options.behaveLikeLine then color.l * 1.2 else color.l * 1.25))

  drawFilledPath: (path, fill) ->
    @raphael.path(path)
      .attr('fill', fill)
      .attr('fill-opacity', @options.fillOpacity)
      .attr('stroke', 'none')
