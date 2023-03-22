import type { VendorTemplate, VendorAction } from "./types";
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';
import yaml from 'js-yaml';

class RecipeManager {
  recipes: { [key: string]: VendorTemplate };

  constructor() {
    // https://flaviocopes.com/fix-dirname-not-defined-es-module-scope/
    const __filename = fileURLToPath(import.meta.url);
    const __dirname = path.dirname(__filename);

    let recipesPath = path.join(__dirname, '../recipes.yml');
    this.recipes = yaml.load(fs.readFileSync(recipesPath).toString()) as { string: VendorTemplate }
  }

  getRecipes(): { [key: string]: VendorTemplate } {
    return this.recipes;
  }
}

export default new RecipeManager();