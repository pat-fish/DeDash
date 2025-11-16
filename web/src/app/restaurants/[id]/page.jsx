
import { restaurants } from "../../../data/restaurants";

export default function Page({ params }) {
    const restaurant = restaurants.find(r => r.id === params.id);

    if (!restaurant) return <p>Restaurant not found</p>;

    return (
        <div className="max-w-xl mx-auto mt-6">
        <h1 className="text-3xl font-bold">{restaurant.name}</h1>
        <p className="text-gray-600 mb-4">{restaurant.cuisine}</p>

        <h2 className="text-xl font-semibold mt-6 mb-2">Menu</h2>
        {restaurant.menu.map(item => (
            <div key={item.id} className="border-b py-2 flex justify-between">
            <span>{item.name}</span>
            <span>${item.price.toFixed(2)}</span>
            </div>
        ))}
        </div>
    );
}
