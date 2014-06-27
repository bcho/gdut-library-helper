# query/library.coffee
# 图书馆查询借口


parser = (require '../parser').library
templates = (require '../templates').library
utils = (require '../utils')


# 构造一个查询接口
#
# @param queryUrlBuilder  查询地址构造函数
# @param filter           查询结果过滤函数
queryFactory = (queryUrlBuilder, filter) ->
  return (queryValue) ->
    dfd = new $.Deferred
    queryUrl = queryUrlBuilder queryValue

    GM_xmlhttpRequest(
      method: 'GET'
      url: queryUrl
      onload: (resp) ->
        parsedResults = parser.parseQueryResults resp.responseText
        if not parsedResults
          dfd.resolve parsedResults
          return

        result = filter(queryValue, parsedResult)
        # 找到一个准确的结果
        if result
          dfd.reject result
        # 找到若干个准确的结果
        else
          dfd.resolve(
            queryUrl: queryUrl
            results: parsedResults
          )
    )

    return dfd.promise()


publisherFilterFactory = (bookMeta) ->
  (value, results) ->
    for result in results
      if result.publisher is bookMeta.publisher
        return result
    return null


module.exports =

  # 根据图书标题进行查询
  title: (bookMeta) ->
    dfd = new $.Deferred

    titleQuery = queryFactory(
      templates.queryTitleURLBuilder
      publisherFilterFactory bookMeta
    )

    utils.convertGB2312(bookMeta.title)
      # FIXME convertGB2312 失败的情况？
      .then(titleQuery)
      # 查询失败，返回失败信息
      .then(dfd.resolve)
      # 查询成功，返回查询结果
      .fail(dfd.reject)

    return dfd.promise()

  # 根据图书 isbn 进行查询
  isbn: (bookMeta) ->
    dfd = new $.Deferred

    isbnQuery = queryFactory(
      templates.queryISBNURLBuilder
      publisherFilterFactory bookMeta
    )

    # 查询 10 位 isbn
    isbnQuery(bookMeta.isbn10)
      # 查询失败，查询 13 位
      .then(-> isbnQuery(bookMeta.isbn13))
      # 查询失败，返回失败信息
      .then(dfd.resolve)
      # （任意一个）查询成功，返回书籍信息
      .fail(dfd.reject)

    return dfd.promise()
