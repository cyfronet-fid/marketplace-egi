import { ScientificDomainFactory } from "cypress/factories/scientific-domain.factory";
import { UserFactory } from "../../../../factories/user.factory";

describe("Scientific Domain", () => {
  const user = UserFactory.create({ roles: ["service_portfolio_manager"] });
  const [
    scientificDomain,
    scientificDomain2,
    scientificDomain3,
    scientificDomain4,
    scientificDomain5,
  ] = [...Array(5)].map(() => ScientificDomainFactory.create());

  const correctLogo = "logo.jpg";
  const wrongLogo = "logo.svg";

  beforeEach(() => {
    cy.visit("/");
    cy.loginAs(user);
  });

  it("should create new scientific domain without parent", () => {
    cy.get("[data-e2e='my-eosc-button']")
      .click();
    cy.get("[data-e2e='backoffice']")
      .click();
    cy.location("href").should("contain", "/backoffice");
    cy.get("[data-e2e='scientific-domains']")
      .click();
    cy.location("href")
      .should("contain", "backoffice/scientific_domains");
    cy.get("[data-e2e='add-new-scientific-domain']")
      .click();
    cy.fillFormCreateScientificDomain(scientificDomain, correctLogo);
    cy.get("[data-e2e='create-scientific-domain-btn']")
      .click();
    cy.location("href").should("contain", `/backoffice/scientific_domains/`);
    cy.get("h1")
      .invoke("text")
      .then((value) => {
        cy.visit("/");
        cy.get("a[href*='services'][data-e2e='branch-link']")
          .contains(value)
          .click();
        cy.location("href").should("contain", `/services?scientific_domains`);
        cy.get("[data-e2e='filter-tag']")
          .should("be.visible")
          .and("contain", value);
      });
  });

  it("should create new scientific domain with parent", () => {
    cy.visit("/backoffice/scientific_domains/new");
    cy.fillFormCreateScientificDomain({ ...scientificDomain2, parent: "Natural Sciences" }, correctLogo);
    cy.get("[data-e2e='create-scientific-domain-btn']")
      .click();
    cy.location("href").should("contain", "/backoffice/scientific_domains/");
    cy.get("h1")
      .invoke("text")
      .then((value) => {
        cy.visit("/services");
        cy.get("#collapse_scientific_domains [data-e2e='filter-checkbox']")
          .next()
          .contains("Natural Sciences")
          .parent()
          .next()
          .next()
          .contains(value)
          .click();
        cy.get("[data-e2e='filter-tag']")
          .should("be.visible")
          .and("contain", value);
      });
  });

  it("should add new scientific domain without logo", () => {
    cy.visit("/backoffice/scientific_domains/new");
    cy.fillFormCreateScientificDomain(scientificDomain3, false);
    cy.get("[data-e2e='create-scientific-domain-btn']")
      .click();
    cy.location("href")
      .should("contain", `/backoffice/scientific_domains/`);
    cy.get("h1")
      .invoke("text")
      .then((value) => {
        cy.visit("/");
        cy.get("a[href*='services'][data-e2e='branch-link']")
          .contains(value)
          .click();
        cy.location("href").should("contain", `/services?scientific_domains`);
        cy.get("[data-e2e='filter-tag']")
          .should("be.visible")
          .and("contain", value);
      });
  });

  it("shouldn't create new scientific domain", () => {
    cy.visit("/backoffice/scientific_domains/new");
    cy.fillFormCreateScientificDomain({ ...scientificDomain4, name: "" }, wrongLogo);
    cy.get("[data-e2e='create-scientific-domain-btn']")
      .click();
    cy.contains(
      "div.invalid-feedback",
      "Logo is not a valid file format and Logo format you're trying to attach is not supported")
      .should("be.visible");
    cy.contains("div.invalid-feedback", "Name can't be blank")
      .should("be.visible");
  });

  it("shouldn't delete scientific domain with successors connected to it", () => {
    cy.visit("/backoffice/scientific_domains");
    cy.get("[data-e2e='backoffice-scientific-domains-list'] li")
      .eq(0)
      .find("a.delete-icon")
      .click();
    cy.get(".alert-danger")
      .contains("This scientific domain has successors connected to it, " +
      "therefore is not possible to remove it. " +
      "If you want to remove it, edit them so they are not associated with this scientific domain anymore")
      .should("be.visible");
  });

  it("shouldn't delete scientific domain with resources connected to it", () => {
    cy.visit("/backoffice/scientific_domains");
    cy.get("[data-e2e='backoffice-scientific-domains-list'] li")
      .contains("Biological Sciences")
      .parent()
      .find("a.delete-icon")
      .click();
    cy.get(".alert-danger")
      .contains("This scientific domain has resources connected to it, remove associations to delete it.")
      .should("be.visible");
  });

  it("should delete scientific domain without resources", () => {
    cy.visit("/backoffice/scientific_domains/new");
    cy.fillFormCreateScientificDomain(scientificDomain5, correctLogo);
    cy.get("[data-e2e='create-scientific-domain-btn']")
      .click();
    cy.get("h1")
      .invoke("text")
      .then((value) => {
        cy.visit("/backoffice/scientific_domains");
        cy.contains(value).parent().find("a.delete-icon").click();
        cy.get(".alert-success")
          .contains("Scientific Domain removed")
          .should("be.visible");
      });
  });

  it("should edit scientific domain", () => {
    cy.visit("/backoffice/scientific_domains");
    cy.get("[data-e2e='backoffice-scientific-domains-list'] li")
      .eq(0)
      .find("a")
      .contains("Edit")
      .click();
    cy.fillFormCreateScientificDomain({ ...scientificDomain, name: "Edited category" }, false);
    cy.get("[data-e2e='create-scientific-domain-btn']")
      .click();
    cy.get(".alert-success")
      .contains("Scientific domain updated correctly")
      .should("be.visible");
  });
});
