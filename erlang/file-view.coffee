{$$} = require 'atom-space-pen-views'
SymbolsView = require './symbols-view'

module.exports =
class FileView extends SymbolsView
  initialize: ->
    super

    @editorsSubscription = atom.workspace.observeTextEditors (editor) =>
      disposable = editor.onDidSave =>
        f = editor.getPath()
        return unless atom.project.contains(f)
        @ctagsCache.generateTags(f, true)

      editor.onDidDestroy -> disposable.dispose()

  destroy: ->
    @editorsSubscription.dispose()
    super

  viewForItem: ({lineNumber, name, file, pattern}) ->
    $$ ->
      @li class: 'two-lines', =>
        @div class: 'primary-line', =>
          @span name, class: 'pull-left'
          @span pattern.substring(2, pattern.length-2), class: 'pull-right'

        @div class: 'secondary-line', =>
          @span "Line: #{lineNumber}", class: 'pull-left'
          @span file, class: 'pull-right'

  toggle: ->
    if @panel.isVisible()
      @cancel()
    else
      editor = atom.workspace.getActiveTextEditor()
      return unless editor
      filePath = editor.getPath()
      return unless filePath
      @cancelPosition = editor.getCursorBufferPosition()
      @populate(filePath)
      @attach()

  cancel: ->
    super
    @scrollToPosition(@cancelPosition, false) if @cancelPosition
    @cancelPosition = null

  toggleAll: ->
    if @panel.isVisible()
      @cancel()
    else
      @list.empty()
      @maxItems = 10
      tags = []
      for key, val of @ctagsCache.cachedTags
        tags.push tag for tag in val
      @f_key = 'name'
      @setItems(tags)
      @attach()

  getCurSymbol: ->
    editor = atom.workspace.getActiveTextEditor()
    if not editor
      console.error "[atom-ctags:getCurSymbol] failed getActiveTextEditor "
      return

    cursor = editor.getLastCursor()
    if cursor.getScopeDescriptor().getScopesArray().indexOf('source.ruby') isnt -1
      # Include ! and ? in word regular expression for ruby files
      range = cursor.getCurrentWordBufferRange(wordRegex: /[\w!?]*/g)
    else if cursor.getScopeDescriptor().getScopesArray().indexOf('source.clojure') isnt -1
      range = cursor.getCurrentWordBufferRange(wordRegex: /[\w\*\+!\-_'\?<>]([\w\*\+!\-_'\?<>\.:]+[\w\*\+!\-_'\?<>]?)?/g)
    else if cursor.getScopeDescriptor().getScopesArray().indexOf('source.erlang') isnt -1
      # 取term位置修改
      range = cursor.getCurrentWordBufferRange(wordRegex: /([\w_\-:]+[\w\-_]*)/g)
    else
      range = cursor.getCurrentWordBufferRange()
    return editor.getTextInRange(range)

  rebuild: ->
    projectPaths = atom.project.getPaths()
    if projectPaths.length < 1
      console.error "[atom-ctags:rebuild] cancel rebuild, invalid projectPath: #{projectPath}"
      return
    @ctagsCache.cachedTags = {}
    @ctagsCache.generateTags projectPath for projectPath in projectPaths

  goto: ->
    symbol = @getCurSymbol()
    if not symbol
      console.error "[atom-ctags:goto] failed getCurSymbol"
      return

    tags = @ctagsCache.findTags(symbol)
    # 跳转这里如果出现多个tag，根据文件名检索
    @f_key = 'file'

    if tags.length < 1
        return
    else if tags.length is 1
      @openTag(tags[0])
    else if @all_in_same_file(tags) is 1
        @openTag(tags[0])
    else
        editor = atom.workspace.getActiveTextEditor()
        cursor = editor.getLastCursor()
        if cursor.getScopeDescriptor().getScopesArray().indexOf('source.erlang') isnt -1
            # erlang 语言中 根据调用模块寻找tags
            ftag = @find_caller(symbol, tags)
            if ftag isnt -1
                # 当前文件匹配，直接跳转
                @openTag(ftag)
            else
                @setItems(tags)
                @attach()
        else
            @setItems(tags)
            @attach()

  all_in_same_file: (tags) ->
      filename = tags[0].file
      return 0 for tag in tags[1..] when tag.file isnt filename
      return -1

  find_caller: (symbol, tags) ->
      aList = symbol.split ":"
      if aList.length > 1
          # 有调用模块, 返回文件名与调用模块相同的tag
          return tag for tag in tags[0..] when @match_file(tag.file, aList[0]) isnt -1
      else
          # 没有调用模块, 返回文件名与当前模块相同的tag
          editor = atom.workspace.getActiveTextEditor()
          curFileName = editor.getTitle().split '.'
          return tag for tag in tags[0..] when @match_file(tag.file, curFileName[0]) isnt -1
      return -1

  match_file:(path, check) ->
      # xxxxx\filename.xxxx
      pattern = /^.*\\([^/]*)\..*$/
      filename=path.match(pattern)[1]
      if filename is check
          return 1
      return -1

  populate: (filePath) ->
    @list.empty()
    @setLoading('Generating symbols\u2026')

    @ctagsCache.getOrCreateTags filePath, (tags) =>
      @maxItem = Infinity
      @f_key='name'
      @setItems(tags)

  scrollToItemView: (view) ->
    super
    return unless @cancelPosition

    tag = @getSelectedItem()
    @scrollToPosition(@getTagPosition(tag))

  scrollToPosition: (position, select = true)->
    if editor = atom.workspace.getActiveTextEditor()
      editor.scrollToBufferPosition(position, center: true)
      editor.setCursorBufferPosition(position)
      editor.selectWordsContainingCursors() if select
