import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  late final database;

  Future<Database> open() async {
    database = openDatabase(
      join(await getDatabasesPath(), "food.db"),
      onCreate: (Database db, int version) async {
        await db.execute("CREATE TABLE foods(id INTEGER PRIMARY KEY, name TEXT NOT NULL, price DOUBLE);"
            "CREATE TABLE plans(id INTEGER PRIMARY KEY, name TEXT NOT NULL, date DATE NOT NULL, targetPrice DOUBLE, foods TEXT);"
            "CREATE TABLE favourites(id INTEGER PRIMARY KEY);");
      },
      version: 1
    );
    return database;
  }

  Future<void> close() async {
    await database.close();
  }

  Future<void> addFood(Food food) async {
    if (food.id == -1) {
      await database.rawInsert("INSERT INTO foods (name, price) values (?,?);", food.name, food.price);
    } else {
      await database.rawReplace("REPLACE INTO foods (name, price) values (?,?) WHERE id = ?;", food.name, food.price, food.id);
    }
  }

  Future<Food> getFood(int id) async {
    Map row = await database.rawQuery("SELECT * FROM foods WHERE id = ? LIMIT 1;", id);
    Food food = Food(row['name'], row['price']);
    food.id = row['id'];
    return food;
  }

  Future<List<Food>> getFoods(String filter) async {
    List<Map> rows;
    if (filter.isEmpty) {
      rows = await database.rawQuery("SELECT * FROM foods;");
    } else {
      rows = await database.rawQuery(
          "SELECT * FROM foods WHERE name LIKE %?%;", filter);
    }
    List<Food> foods = List<Food>.empty(growable: true);
    for (Map row in rows) {
      Food food = Food(row['name'], row['price']);
      food.id = row['id'];
      foods.add(food);
    }
    return foods;
  }

  Future<void> addPlan(Plan plan) async {
    List<int> foodIds = List<int>.empty(growable: true);
    for (Food food in plan.foods) {
      foodIds.add(food.id);
    }
    String jsonArr = jsonEncode(foodIds);
    if (plan.id == -1) {
      await database.rawInsert("INSERT INTO plans (name, date, targetPrice, foods) values (?,?,?,?);", plan.name, plan.date, (plan.targetPrice == -1) ? null : plan.targetPrice, jsonArr);
    } else {
      await database.rawReplace("REPLACE INTO plans (name, date, targetPrice, foods) values (?,?,?,?) WHERE id = ?;", plan.name, plan.date, (plan.targetPrice == -1) ? null : plan.targetPrice, jsonArr, plan.id);
    }
  }

  Future<Plan> getPlan(int id) async {
    Map row = await database.rawQuery("SELECT * FROM plans WHERE id = ?;", id);
    Plan plan = Plan(row['name'], DateTime.parse(row['date']));
    plan.id = row['id'];
    plan.targetPrice = (row['targetPrice'] == null) ? -1 : row['targetPrice'];
    plan.foods = jsonDecode(row['foods']);
    return plan;
  }

  Future<List<Plan>> getPlans(String name) async {
    List<Plan> plans = List<Plan>.empty(growable: true);
    List<Map> rows;
    if (name.isEmpty) {
      rows = await database.rawQuery("SELECT * FROM plans;");
    } else {
      rows = await database.rawQuery("SELECT * FROM plans WHERE name LIKE %?%;", name);
    }
    for (Map row in rows) {
      Plan plan = Plan(row['name'], DateTime.parse(row['date']));
      plan.id = row['id'];
      plan.targetPrice = (row['targetPrice'] == null) ? -1 : row['targetPrice'];
      plan.foods = jsonDecode(row['foods']);
      plans.add(plan);
    }
    return plans;
  }

  Future<List<Plan>> getPlansWithPrice(String name, double maxPrice) async {
    List<Plan> plans = List<Plan>.empty(growable: true);
    List<Map> rows;
    if (name.isEmpty) {
      rows = await database.rawQuery("SELECT * FROM plans WHERE targetPrice <= ?;", maxPrice);
    } else {
      rows = await database.rawQuery("SELECT * FROM plans WHERE name LIKE %?% AND targetPrice <= ?;", name, maxPrice);
    }
    for (Map row in rows) {
      Plan plan = Plan(row['name'], DateTime.parse(row['date']));
      plan.id = row['id'];
      plan.targetPrice = (row['targetPrice'] == null) ? -1 : row['targetPrice'];
      plan.foods = jsonDecode(row['foods']);
      plans.add(plan);
    }
    return plans;
  }

  Future<void> addFavourite(int id) async {
    await database.rawInsert("INSERT INTO favourites (id) values (?);", id);
  }

  Future<List<Food>> getFavourites() async {
    List<Map> rows = await database.rawQuery("SELECT id FROM favourites;");
    List<Food> foods = List<Food>.empty(growable: true);
    for (Map row in rows) {
      foods.add(await getFood(row['id']));
    }
    return foods;
  }
}

class Food {
  int id = -1;
  String name;
  double price;

  Food(this.name, this.price);
}

class Plan {
  int id = -1;
  String name;
  DateTime date;
  double targetPrice = -1.0;
  var foods = List<Food>.empty(growable: true);

  Plan (this.name, this.date);
}

