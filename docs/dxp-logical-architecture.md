# Episerver/Optimizely DXP Logical Architecture

## Main contents:
- [Fullstack & API](#1-fullstack--api)
- [Data Platform](#2-data-platform)
- [Content cloud](#3-content-cloud)
- [Commerce cloud](#4-commerce-cloud)

### 1. Fullstack & API
- Provide for developers.

### 2. Data Platform
- Manage CDP activations for campaign

- Features:
  - <a name="data-platform-data-core-services"></a>**Data Core Services**:
    - Import CDP segments for personalisation
    - Use website tracking
    - Use [Web Experimentation](#content-cloud-web-experimentation) tracking
    - Use [content interests](#content-cloud-content) tracking
  - **Enterprise Resource Planning**: 
    - Manage products, pricing, inventory,...
  - **Order Management System**
  - **1st/3rd Party Data**: 
    - Optimize data, intergrations,...
  - **Advertising**:
    - Use data activations
  - **Email & SMS Campaigns**:
    - Use email & SMS campaign activations
  - **Mobile App**:
    - Push notifications
  - **API Channel**:
    - Trigger API

### 3. Content cloud
- Technology information:
  - Newest version: 12
  - Build on .NET 5, with support .NET 6
- Features:
  - For **author, collaborate, test, manage**
  - <a name="content-cloud-search-navigation"></a>**Search & Navigation**:
    - E.g.: Content indexing, search results,...
  - **Community API**:
    - E.g.: Ratings, reviews,...
  - <a name="content-cloud-web-experimentation"></a>**Web Experimentation**:
    - Manage for campaign
    - Improve UX
    - Use customer data in experiments from [Data Platform](#2-data-platform)
  - <a name="content-cloud-content"></a>**Content Intelligence & Recommendations**:
    - Get content scraping & topic analysis
    - Use machine learning to provide content recommendations

### 4. Commerce cloud
- Products:
  - [B2B](#41-b2b)
  - [B2C](#42-b2c)
  - [Product information management (PIM)](#43-product-information-management-pim)
- Features:
  - **Product Information Management**:
    - E.g.: catalog, checkout, order, promote
  - **Product Recommendations**: 
    - Personalise [Search & Navigation](#content-cloud-search-navigation)
    - Use machine learning to provide recommendations in email

#### 4.1. B2B
- Manage all from one holistic view
- Match the right digital experience by using AI
- Providing data-driven recommendations
- Capabilities:
  - B2B:
    - Brand management
    - Customer
    - List management
    - Quotations
    - [Product information management (PIM)](#43-product-information-management-pim)
    - Product configuration
  - [Shopping](#other-sections-shopping)
  - [Management](#other-sections-management)
  - [Technology](#other-sections-technology):
    - Others: analytics, native mobile app

#### 4.2. B2C
- Align with customer needs
- Launch and grow fast
- Scale business
- Capabilities:
  - [Shopping](#other-sections-shopping)
  - [Management](#other-sections-management)
  - [Technology](#other-sections-technology):
    - Others: A/B testing

#### 4.3. Product Information Management (PIM)
- Manage, import, customize products

---
---
##### Other sections:
- **Capabilities**:
  - <a name="other-sections-shopping"></a>**Shopping**:
    - Approval workflows
    - Checkout & cart
    - Management of orders, quotes, addresses, jobs, custom lists, viewed products
    - Search & navigation:
      - Filter by store location or anything
      - Shipping and fulfillment method
      - Sort
    - Promotions
    - Targeting
  - <a name="other-sections-management"></a>**Management**:
    - Catalog:
      - Brands, categories, price, products...
    - Content
    - Dashboard:
      - CMS, customers, import/export, marketing, promotions,...
    - Media
    - Order
    - Project:
      - Integration connection, jobs, roles, system, website users...
    - Sales:
      - Cart/orders history, payment methods, transactions...
  - <a name="other-sections-technology"></a>**Technology**:
    - Analytics
    - Built on .NET and Azure
    - [Data Core Service](#data-platform-data-core-services)
    - Headless:
      - Present products across all applications
    - Localization
    - Multisite
    - Native mobile app
