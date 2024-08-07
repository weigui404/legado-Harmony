import DbUtil from '../../common/utils/DbUtil';
import toolsUtils from '../../common/utils/ToolsUtils';
import AppDatabaseUtil from '../AppDatabaseUtil';
import { Books } from '../entities/Books';
import { BooksTypeSearchParams } from '../types/BooksType';
import { ColumnInfo } from '../types/ColumnInfo';

class BooksDao {
  TABLE_NAME: string = 'books'

  // 创建books数据表
  async initBooksTable() {
    try {
      const createSql = AppDatabaseUtil.getCreateSql(this.TABLE_NAME);
      if (!createSql) {
        return
      }
      await DbUtil.createTable(createSql)
      AppDatabaseUtil.existsTable(this.TABLE_NAME)
      return
    } catch (err) {
      console.info('TagInfo', JSON.stringify(err))
    }
  }

  async search(param?:BooksTypeSearchParams) {
    let searchKey = param?.searchKey ?? '';
    let type = param?.type;
    let bookGroup = param?.bookGroup;
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      let sql = `SELECT * FROM ${this.TABLE_NAME}`;
      // 动态添加 WHERE 子句
      let whereClause: string[] = [];
      if (type !== undefined) {
        whereClause.push(`bookType = ${type}`);
      }
      if (bookGroup !== undefined && bookGroup !== 2) {
        whereClause.push(`bookGroup = ${bookGroup}`);
      }
      if (searchKey) {
        whereClause.push(`(
        bookName LIKE '%${searchKey}%'
        author LIKE '%${searchKey}%'
        originName LIKE '%${searchKey}%'
      )`);

      }
      // 如果有 where 子句，添加 WHERE 关键字
      if (whereClause.length > 0) {
        sql += ` WHERE ${whereClause.join(' AND ')}`;
      }
      sql += `
  ORDER BY
     isTop DESC, createTime DESC
`;
      const bookDbList = await DbUtil.querySqlForList<Books>(sql, column);
      console.log("TagInfo", '书籍：' + bookDbList.length)
      return bookDbList
    } catch (err) {
      console.log("TagInfo", JSON.stringify(err))
      return []
    }
  }

  async batchInsert(books: Books[]) {
    try {
      for (let index = 0; index < books.length; index++) {
        const book = books[index];
        await this.insert(book)
      }
      return true
    } catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err))
      return false
    }
  }

  async insert(books: Books) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      if (books.id) {
        const predicates = DbUtil.getPredicates(this.TABLE_NAME);
        predicates.equalTo('id', books.id)
        const count = await DbUtil.queryForCount(predicates, column)
        if (count > 0) {
          this.update(books)
          return true
        }
      }
      books.createTime = Date.now()
      await DbUtil.insert(this.TABLE_NAME, books, column)
      console.log('TagInfo', '创建成功')
      return true
    } catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err))
      return false
    }
  }

  async update(books: Books) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('id', books.id)
      const count = await DbUtil.queryForCount(predicates, column)
      if (count === 0 && books instanceof Books) {
        this.insert(books)
        return true
      }
      await DbUtil.update(predicates, books, column)
      return true
    } catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err))
      return false
    }
  }
  //置顶
  async isUpdateBookTop(id: number, isTop: boolean) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('id', id)
      const count = await DbUtil.queryForList<Books>(predicates, column)
      if (column.length > 0) {
        count.forEach((item) => {
          item.isTop = isTop
          item.updateTime = Date.now()
          this.update(item)
        })
        return true
      }
      return false
    } catch (err) {
      console.log('isUpdateBookTop, Error, ', JSON.stringify(err))
      return false
    }
  }
  //批量更新书籍分组
  async batchUpdateBookGroup(id: number[],groupId:number) {
    try {
      for (let index = 0; index < id.length; index++) {
       this.updateBookGroup(id[index],groupId)
      }
      return true
    } catch (err) {
      console.log('batchUpdateBookGroup, Error, ', JSON.stringify(err))
      return false
    }
  }
  //更新书籍分组
  async updateBookGroup(bookIds: number|number[],groupId:number) {
    try {
      let Ids: number[] = toolsUtils.numberArrays(bookIds)
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const validIds = Ids.filter(id => typeof id === 'number');
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('id', validIds)
      const count = await DbUtil.queryForList<Books>(predicates, column)
      if (count.length > 0) {
        count.forEach(async (item) => {
          item.bookGroup = groupId
          await this.update(item)
        })
        return true
      }
      return false
    } catch (err) {
      console.log('updateBookGroup, Error, ', JSON.stringify(err))
      return false
    }
  }

  //根据书籍获取旧的分组Id
  async getBookIdsByGroupId(ids: number[]) {
    let BookGroupId: Record<number, number> = {};
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);

      // 确保 ids 数组的每个元素都是数字
      const validIds = ids.filter(id => typeof id === 'number');

      // 创建查询条件，查找所有给定的 id
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('id', validIds);  // 使用 in 条件一次性查找多个 id

      // 执行一次查询获取所有匹配的书籍
      const books = await DbUtil.queryForList<Books>(predicates, column);

      // 遍历查询结果，将书籍的 bookGroup 分组
      books.forEach(book => {
        const bookId = book.id;  // 获取书籍的 id
        if (bookId !== undefined) {
          if (!BookGroupId[bookId]) {
            BookGroupId[bookId] = 0;
          }
          BookGroupId[bookId] = book.bookGroup ?? 0;
        }
      });

      return BookGroupId;
    } catch (e) {
      console.log('getBookIdsByGroupId, Error, ', JSON.stringify(e));
      return [];
    }
  }

  //根据分组获取书籍id
  async queryBooksByGroupId(groupId: number[]){
    let GroupBookId: number[] = [];
    try {
      // 确保 ids 数组的每个元素都是数字
      const validIds = groupId.filter(id => typeof id === 'number');
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('bookGroup', validIds)
      // 执行一次查询获取所有匹配的书籍
      const books = await DbUtil.queryForList<Books>(predicates, column);
      // 遍历查询结果，将书籍的 bookGroup 分组
      books.forEach(book => {
        const bookId = book.id;  // 获取书籍的 id
        if (bookId !== undefined) {
          GroupBookId.push(bookId)
        }
      });
      return GroupBookId
    } catch (e) {
      console.log('queryBooksByGroupId, Error, ', JSON.stringify(e));
      return []
    }
  }

  //删除订阅源历史记录
  async deleteBook(id: number[]) {
    try {
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('id', id)
      await DbUtil.delete(predicates)
      return true
    }  catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err))
      return false
    }
  }

  //根据分组id统计书籍数量
  async countBookByGroup(groupId: number) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.equalTo('bookGroup', groupId)
      const count = await DbUtil.queryForCount(predicates, column)
      return count
    } catch (err) {
      console.log('TagInfo, Error, ', JSON.stringify(err))
      return 0
    }
  }

  //分组删除情况下根据删除分组id查询书籍更新未分组
  async queryBookByGroup(groupId: number[],updateGroupId: number) {
    try {
      const column: ColumnInfo[] = AppDatabaseUtil.getColumn(this.TABLE_NAME);
      const predicates = DbUtil.getPredicates(this.TABLE_NAME);
      predicates.in('bookGroup', groupId)
      const bookDbList = await DbUtil.queryForList<Books>(predicates, column)
      if (bookDbList.length > 0) {
        bookDbList.forEach((item) => {
          item.bookGroup = updateGroupId
          this.update(item)
        })
      }
    } catch (e) {
      console.log('TagInfo, Error, ', JSON.stringify(e))
    }
  }
}


const booksDao = new BooksDao()
export default booksDao as BooksDao